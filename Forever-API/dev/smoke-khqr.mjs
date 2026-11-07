// DEV/TEST ONLY — end-to-end smoke test of the live API: stock fields, guest cart, KHQR checkout (with a
// retried submission), and payment confirmation via dev/fake-bakong.mjs. Needs the API started with
// KHQR_API_URL pointing at the fake (see fake-bakong.mjs).   node dev/smoke-khqr.mjs
import { execFileSync } from 'node:child_process';

const API = process.env.API || 'http://localhost:8989';
const FAKE = process.env.FAKE_BAKONG || 'http://localhost:9099';
let failures = 0;
const check = (ok, label, extra = '') => { console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${extra ? '  ' + extra : ''}`); if (!ok) failures++; };
const call = async (method, path, headers, body) => {
  const res = await fetch(API + path, { method, headers: { 'content-type': 'application/json', ...(headers || {}) }, body: body ? JSON.stringify(body) : undefined });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : null };
};
const sql = (q) => execFileSync('docker', ['exec', 'forever-postgres', 'psql', '-U', 'forever', '-d', 'forever', '-tAc', q]).toString().trim();

const latest = (await call('GET', '/api/products/latest?limit=10')).body;
const product = latest.find((p) => p.inStock);
check(latest.every((p) => p.stock && Object.keys(p.stock).join() === p.sizes.join()), 'every product has per-size stock in size order');
const size = Object.entries(product.stock).find(([, q]) => q > 0)[0];
const dbStock = Number(sql(`select stock from product_inventory where product_id=${product.id} and size='${size}'`));
check(dbStock === product.stock[size], 'API stock matches the database', `${product.name} ${size}: api=${product.stock[size]} db=${dbStock}`);

const session = (await call('POST', '/api/guest-sessions')).body;
check(session.token && !session.user && !session.accessToken, 'anonymous guest cart session issued (not a login)');
const t = { 'x-guest-session': session.token };
const added = await call('POST', '/api/cart/items', t, { productId: product.id, size, quantity: 1 });
check(added.status === 200 && added.body.items[0].stock === dbStock, 'guest add-to-cart works and reports stock', `status=${added.status}`);
const over = await call('POST', '/api/cart/items', t, { productId: product.id, size, quantity: 99 });
check(over.status === 409 && over.body.code === 'OUT_OF_STOCK', 'adding beyond stock is refused', `${over.status} ${over.body?.message}`);

const body = { address: { firstName: 'Smoke', lastName: 'Test', email: 'smoke@example.com', street: '1 Main', city: 'PP', state: 'PP', zipcode: '12000', country: 'KH', phone: '012' }, paymentMethod: 'KHQR', idempotencyKey: `smoke-${Date.now()}` };
const [a, b] = await Promise.all([call('POST', '/api/khqr/checkout', t, body), call('POST', '/api/khqr/checkout', t, body)]);
check(a.status === 200 && b.status === 200, 'two simultaneous KHQR submissions both answered', `${a.status}/${b.status} ${a.body?.message || ''}`);
check(a.body.orderId === b.body.orderId && a.body.qrString === b.body.qrString, 'same order and same QR for both');
const id = a.body.orderId;
check(sql(`select count(*) from orders where idempotency_key='${body.idempotencyKey}'`) === '1', 'exactly one order row in the database');

const a1 = { 'x-order-access': a.body.guestAccessToken };
check(!!a.body.guestAccessToken && a.body.guestAccessToken === b.body.guestAccessToken, 'guest gets one order-access token, same on the retried submission');
const before = (await call('POST', `/api/guest-orders/${id}/khqr/verify`, a1)).body;
check(!before.paid && before.status === 'PENDING', 'unpaid QR verifies as PENDING');
const [md5, total, status0] = sql(`select khqr_md5||'|'||total||'|'||status from orders where id=${id}`).split('|');
check(status0 === 'PAYMENT_PENDING', 'order is PAYMENT_PENDING in the database before payment');
await fetch(`${FAKE}/__pay`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ md5, amount: Number(total) }) });
const after = (await call('POST', `/api/guest-orders/${id}/khqr/verify`, a1)).body;
check(after.paid && after.status === 'PAID', 'after the (simulated) payment it verifies as PAID');
check(sql(`select status||' '||paid from orders where id=${id}`) === 'ORDER_PLACED true', 'database shows ORDER_PLACED, paid');
const other = { 'x-guest-session': (await call('POST', '/api/guest-sessions')).body.token };
check((await call('GET', `/api/guest-orders/${id}`, other)).status === 404, "another guest can't read the order");
check((await call('GET', `/api/guest-orders/${id}`, a1)).status === 200, 'the placing guest can open its confirmation');
check(sql(`select count(*) from orders where id=${id} and user_id is null`) === '1', 'stored as a guest order, attached to no account');

console.log(failures ? `\n${failures} FAILED` : '\nALL PASSED');
process.exit(failures ? 1 : 0);
