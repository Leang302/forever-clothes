// DEV/TEST ONLY — a stand-in for Bakong's Open API so the KHQR flow can be exercised end to end
// without real money. Never point a production API at this.
//
//   node dev/fake-bakong.mjs            # listens on :9099
//   KHQR_API_URL=http://localhost:9099 KHQR_ACCOUNT_ID=forever_test@aclb KHQR_API_TOKEN=dev-fake ./gradlew bootRun
//
// Simulate the customer paying a QR (amount must equal the order total, or the API ignores it):
//   curl -X POST localhost:9099/__pay -H 'content-type: application/json' -d '{"md5":"<orders.khqr_md5>","amount":123.45}'
// The md5/total for an order: docker exec forever-postgres psql -U forever -d forever -tAc \
//   "select khqr_md5, total from orders where id = 42"
import http from 'node:http';
import { createHash } from 'node:crypto';

const PORT = Number(process.env.FAKE_BAKONG_PORT || 9099);
const paid = new Map(); // md5 -> amount
let lastCheck = null;

const json = (res, status, body) => {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
};

const readBody = (req) => new Promise((resolve) => {
  let data = '';
  req.on('data', (c) => { data += c; });
  req.on('end', () => { try { resolve(data ? JSON.parse(data) : {}); } catch { resolve({}); } });
});

http.createServer(async (req, res) => {
  const body = await readBody(req);
  if (req.method === 'POST' && req.url === '/v1/check_transaction_by_md5') {
    lastCheck = { md5: body.md5, auth: req.headers.authorization, at: new Date().toISOString() };
    if (!req.headers.authorization?.startsWith('Bearer ')) return json(res, 401, { responseCode: 1, responseMessage: 'Unauthorized' });
    if (!paid.has(body.md5)) return json(res, 200, { responseCode: 1, responseMessage: 'Transaction could not be found.', data: null });
    return json(res, 200, { responseCode: 0, responseMessage: 'Getting transaction successfully.',
      data: { hash: `fake-${body.md5.slice(0, 8)}`, amount: paid.get(body.md5), currency: 'USD' } });
  }
  if (req.method === 'POST' && req.url === '/__pay') {
    if (!body.md5 || body.amount == null) return json(res, 400, { error: 'md5 and amount are required' });
    paid.set(body.md5, Number(body.amount));
    return json(res, 200, { ok: true, paid: Object.fromEntries(paid) });
  }
  if (req.method === 'POST' && req.url === '/__pay_qr') {
    // Pay by the QR string a client was shown (Bakong's MD5 is the MD5 of that payload).
    if (!body.qr || body.amount == null) return json(res, 400, { error: 'qr and amount are required' });
    const md5 = createHash('md5').update(body.qr).digest('hex');
    paid.set(md5, Number(body.amount));
    return json(res, 200, { ok: true, md5 });
  }
  if (req.method === 'GET' && req.url === '/__state') return json(res, 200, { paid: Object.fromEntries(paid), lastCheck });
  return json(res, 404, { error: 'not found' });
}).listen(PORT, () => console.log(`fake Bakong listening on http://localhost:${PORT} (DEV ONLY)`));
