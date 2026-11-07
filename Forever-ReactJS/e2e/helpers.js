// Shared helpers for the E2E specs: admin API access, the Postgres container, the dev-only fake Bakong,
// and a `page` fixture that records console errors / page errors.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { test as base, expect } from '@playwright/test';

export const API = process.env.E2E_API_URL || 'http://localhost:8989';
export const FAKE_BAKONG = process.env.E2E_BAKONG_URL || 'http://localhost:9099';
export const ADMIN = { email: 'admin@forever.com', password: 'Admin@12345' };

/** Runs SQL in the dev Postgres container and returns the trimmed `psql -tA` output. */
export const psql = (sql) =>
  execFileSync('docker', ['exec', 'forever-postgres', 'psql', '-U', 'forever', '-d', 'forever', '-tAc', sql], {
    encoding: 'utf8',
  }).trim();

const sqlString = (value) => `'${String(value).replace(/'/g, "''")}'`;
export const sql = { str: sqlString };

async function json(res) {
  const text = await res.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return text;
  }
}

export async function apiCall(path, { method = 'GET', token, guest, body, form } = {}) {
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (guest) headers['X-Guest-Session'] = guest;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const res = await fetch(API + path, { method, headers, body: form ?? (body === undefined ? undefined : JSON.stringify(body)) });
  const data = await json(res);
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${JSON.stringify(data)}`);
  return data;
}

export async function adminToken() {
  const res = await apiCall('/api/auth/login', { method: 'POST', body: ADMIN });
  return res.accessToken;
}

/** An image URL the API already serves, so fixture products can be created with `imageUrls` alone. */
export async function anyImageUrl() {
  const latest = await apiCall('/api/products/latest?limit=1');
  return latest[0].images[0];
}

/**
 * Creates a throwaway product through the admin API in ONE multipart request (imageUrls + stock + active),
 * the same contract the admin form uses. Name is unique so specs can find it.
 */
export async function createFixtureProduct(token, { name, price = '12.50', sizes = ['S', 'M', 'L'], stock = 10, active = true } = {}) {
  const form = new FormData();
  form.append('name', name);
  form.append('description', `E2E fixture product ${name}. Safe to ignore.`);
  form.append('price', price);
  form.append('category', 'Men');
  form.append('subCategory', 'Topwear');
  sizes.forEach((s) => form.append('sizes', s));
  form.append('bestseller', 'false');
  form.append('imageUrls', await anyImageUrl());
  form.append('active', String(active));
  form.append('stock', String(stock));
  return apiCall('/api/admin/products', { method: 'POST', token, form });
}

export const setStock = (token, productId, size, stock) =>
  apiCall(`/api/admin/inventory/${productId}/${size}`, { method: 'PUT', token, body: { stock } });

/** The admin "delete" is a soft delete (product hidden from the shop); orders keep referring to it. */
export const deleteProduct = (token, id) => apiCall(`/api/admin/products/${id}`, { method: 'DELETE', token });

/** Simulates the customer paying a KHQR code at the dev-only fake Bakong. */
export async function payQr(qr, amount) {
  const res = await fetch(`${FAKE_BAKONG}/__pay_qr`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ qr, amount }),
  });
  if (!res.ok) throw new Error(`fake Bakong /__pay_qr -> ${res.status}`);
  return res.json();
}

const randomIp = () =>
  `10.${Math.floor(Math.random() * 250)}.${Math.floor(Math.random() * 250)}.${Math.floor(Math.random() * 250) + 1}`;

/** Starts an anonymous guest cart session through the API (as its own client address, see the `page` fixture). */
export async function apiGuestSession() {
  const res = await fetch(`${API}/api/guest-sessions`, { method: 'POST', headers: { 'X-Forwarded-For': randomIp() } });
  if (!res.ok) throw new Error(`POST /api/guest-sessions -> ${res.status} ${await res.text()}`);
  return res.json(); // { token, expiresAt }
}

/** A guest places a cash-on-delivery order through the API; resolves the OrderResponse (with guestAccessToken). */
export async function apiGuestCodOrder({ productId, size, quantity, address }) {
  const { token: guest } = await apiGuestSession();
  await apiCall('/api/cart/items', { method: 'POST', guest, body: { productId, size, quantity } });
  return apiCall('/api/orders', {
    method: 'POST',
    guest,
    body: { address, paymentMethod: 'COD', shippingMethod: 'STANDARD', idempotencyKey: crypto.randomUUID() },
  });
}

/** sha256 hex of a guest token, as stored in guest_sessions.token_hash. */
export const tokenHash = (token) => createHash('sha256').update(token, 'utf8').digest('hex');

/** Latest 6-digit code Mailpit (dev SMTP sink) received for `email`. */
export async function latestOtp(email) {
  const MAILPIT = process.env.E2E_MAILPIT_URL || 'http://localhost:8025';
  for (let i = 0; i < 30; i += 1) {
    const search = await (await fetch(`${MAILPIT}/api/v1/search?query=${encodeURIComponent(`to:"${email}"`)}&limit=1`)).json();
    const id = search.messages?.[0]?.ID;
    if (id) {
      const msg = await (await fetch(`${MAILPIT}/api/v1/message/${id}`)).json();
      const code = (msg.Text || msg.HTML || '').match(/\b(\d{6})\b/);
      if (code) return code[1];
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`no OTP email for ${email}`);
}

/** Deletes a test account the specs created, unless it has orders (cart/tokens/addresses cascade). */
export function deleteTestUser(email) {
  psql(`delete from users where email = ${sqlString(email)} and not exists (select 1 from orders o where o.user_id = users.id)`);
}

/** Clean-up for a fixture product: deletes the guest test orders (e2e+…@example.com) that contain it, then the product. */
export function cleanupFixtureProduct(id) {
  const n = Number(id);
  psql(`delete from orders where user_id is null and email like 'e2e+%@example.com'
          and id in (select order_id from order_items where product_id = ${n})`);
  return hardDeleteUnorderedProduct(n);
}

/** Deletes the guest orders (user_id null) the specs placed with test emails (e2e+<tag>@example.com). */
export function deleteTestOrders(email) {
  const e = sqlString(email);
  psql(`delete from order_items where order_id in (select id from orders where email = ${e} and user_id is null);
        delete from orders where email = ${e} and user_id is null`);
}

/**
 * Instruments a page of the storefront:
 *  - every request to the API is recorded with the identity headers it carried (`identityLog`), so specs
 *    can assert no request ever sends BOTH Authorization and X-Guest-Session;
 *  - POST /api/guest-sessions gets its own client address (X-Forwarded-For; the API runs behind a trusted
 *    local proxy setting), so repeated suite runs don't exhaust the real 20-sessions-per-IP-per-hour limit.
 *    Each test is a "different shopper"; the app code path is unchanged.
 */
export async function instrument(page, identityLog = []) {
  page.on('request', (r) => {
    if (!r.url().startsWith(API)) return;
    const h = r.headers();
    identityLog.push({
      method: r.method(),
      path: new URL(r.url()).pathname,
      authorization: !!h.authorization,
      guest: !!h['x-guest-session'],
      orderAccess: !!h['x-order-access'],
    });
  });
  const fakeIp = randomIp();
  await page.route('**/api/guest-sessions', (route) =>
    route.continue({ headers: { ...route.request().headers(), 'x-forwarded-for': fakeIp } }),
  );
  return identityLog;
}

/** No request carried two identities, and the guest/order-access headers only went where they belong. */
export function expectCleanIdentities(identityLog) {
  const both = identityLog.filter((r) => r.authorization && r.guest);
  expect(both, 'requests with BOTH Authorization and X-Guest-Session').toEqual([]);
  const guestAllowed = (r) => /^\/api\/(cart|checkout)(\/|$)/.test(r.path)
    || (r.method === 'POST' && ['/api/orders', '/api/khqr/checkout'].includes(r.path))
    || (r.method === 'DELETE' && r.path === '/api/guest-sessions/current');
  expect(identityLog.filter((r) => r.guest && !guestAllowed(r)), 'X-Guest-Session sent outside cart/checkout').toEqual([]);
  expect(identityLog.filter((r) => r.orderAccess && !r.path.startsWith('/api/guest-orders/')), 'X-Order-Access outside guest-orders')
    .toEqual([]);
  expect(identityLog.filter((r) => r.orderAccess && (r.authorization || r.guest)), 'X-Order-Access mixed with another identity')
    .toEqual([]);
}

/** Removes a product the specs created and that no order refers to (the admin delete only hides it). */
export function hardDeleteUnorderedProduct(id) {
  const n = Number(id);
  if (psql(`select count(*) from order_items where product_id = ${n}`) !== '0') return false;
  psql(`delete from cart_items where product_id = ${n}; delete from wishlist_items where product_id = ${n};
        delete from product_inventory where product_id = ${n}; delete from product_images where product_id = ${n};
        delete from product_sizes where product_id = ${n}; delete from products where id = ${n};`);
  return true;
}

export const uniqueTag = () => `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;

/**
 * `page` fixture that:
 *  - records console errors/warnings and uncaught page errors (`consoleProblems`), failing the test on
 *    any uncaught page error;
 *  - is `instrument()`ed (own client address for guest sessions + identity-header log), and fails the test
 *    if any request carried both Authorization and X-Guest-Session (or sent a guest/order-access header
 *    where it doesn't belong).
 */
export const test = base.extend({
  consoleProblems: async ({}, use) => { // eslint-disable-line no-empty-pattern
    await use([]);
  },
  identityLog: async ({}, use) => { // eslint-disable-line no-empty-pattern
    await use([]);
  },
  page: async ({ page, consoleProblems, identityLog }, use) => {
    page.on('console', (msg) => {
      if (msg.type() === 'error' || msg.type() === 'warning') consoleProblems.push(`[${msg.type()}] ${msg.text()}`);
    });
    const pageErrors = [];
    page.on('pageerror', (err) => pageErrors.push(err.message));
    await instrument(page, identityLog);
    await use(page);
    expect(pageErrors, 'uncaught errors in the page').toEqual([]);
    expectCleanIdentities(identityLog);
  },
});

export { expect };

/** Fills the checkout address form. */
export async function fillCheckout(page, values) {
  for (const [name, value] of Object.entries(values)) {
    await page.locator(`input[name="${name}"]`).fill(value);
  }
}

export const checkoutDetails = (tag) => ({
  firstName: 'Sokha',
  lastName: `Tester${tag}`,
  email: `e2e+${tag}@example.com`,
  street: '12 Street 240',
  city: 'Phnom Penh',
  state: 'Daun Penh',
  zipcode: '12207',
  country: 'Cambodia',
  phone: `+85512${String(Date.now()).slice(-6)}`,
});
