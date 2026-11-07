// Checkout retries / idempotency keys, lazy guest cart sessions and the guest rate-limit message.
import {
  adminToken, checkoutDetails, cleanupFixtureProduct, createFixtureProduct, deleteProduct, expect, fillCheckout, psql, sql, test,
  uniqueTag,
} from './helpers.js';

let token;
let product;

test.beforeAll(async () => {
  token = await adminToken();
  product = await createFixtureProduct(token, { name: `E2E Retry Tee ${uniqueTag()}`, price: '8.00', stock: 20 });
});

test.afterAll(async () => {
  if (product) {
    await deleteProduct(token, product.id);
    cleanupFixtureProduct(product.id);
  }
});

async function toCheckout(page, details) {
  await page.goto(`/product/${product.id}`);
  await page.getByRole('button', { name: 'Size M', exact: true }).click();
  await page.getByRole('button', { name: 'Add to Cart', exact: true }).click();
  await expect(page.getByText('Added to cart (1 × size M)')).toBeVisible();
  await page.goto('/place-order');
  await fillCheckout(page, details);
  await page.getByRole('button', { name: /Cash on Delivery/ }).click();
}

test('visiting /cart and /place-order without a session does not start a guest session', async ({ page }) => {
  const guestCalls = [];
  page.on('request', (r) => r.url().endsWith('/api/guest-sessions') && guestCalls.push(r.url()));
  await page.goto('/cart');
  await expect(page.getByText('Your cart is empty')).toBeVisible();
  await page.goto('/place-order');
  await expect(page).toHaveURL(/\/cart$/);
  await page.waitForLoadState('networkidle');
  expect(guestCalls).toEqual([]);
});

test('lost response: retrying the same details reuses the key and yields the original order (no duplicate)', async ({ page }) => {
  const details = checkoutDetails(uniqueTag());
  await toCheckout(page, details);

  const keys = [];
  let first = true;
  await page.route('**/api/orders', async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    keys.push(JSON.parse(route.request().postData()).idempotencyKey);
    if (first) {
      first = false;
      await route.fetch(); // the server DOES create the order...
      return route.abort('failed'); // ...but the browser never gets the answer
    }
    return route.continue();
  });

  await page.getByRole('button', { name: 'Place order' }).click();
  await expect(page.getByTestId('order-error')).toContainText('Cannot reach the server');
  expect(psql(`select count(*) from orders where email = ${sql.str(details.email)}`)).toBe('1');

  await page.getByRole('button', { name: 'Place order' }).click(); // retry, same details
  await expect(page).toHaveURL(/\/order-confirmation\/\d+$/);
  expect(keys).toHaveLength(2);
  expect(keys[1]).toBe(keys[0]);
  const orderId = page.url().split('/').pop();
  expect(psql(`select count(*) || '|' || max(id) from orders where email = ${sql.str(details.email)}`)).toBe(`1|${orderId}`);
});

test('changing checkout details after a failed attempt uses a NEW idempotency key', async ({ page }) => {
  const details = checkoutDetails(uniqueTag());
  await toCheckout(page, details);
  const keys = [];
  let first = true;
  await page.route('**/api/orders', async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    keys.push(JSON.parse(route.request().postData()).idempotencyKey);
    if (first) {
      first = false;
      return route.abort('failed'); // never reaches the server
    }
    return route.continue();
  });
  await page.getByRole('button', { name: 'Place order' }).click();
  await expect(page.getByTestId('order-error')).toBeVisible();
  await page.locator('input[name="city"]').fill('Siem Reap'); // details changed
  await page.getByRole('button', { name: 'Place order' }).click();
  await expect(page).toHaveURL(/\/order-confirmation\/\d+$/);
  expect(keys).toHaveLength(2);
  expect(keys[1]).not.toBe(keys[0]);
  expect(psql(`select count(*) || '|' || max(city) from orders where email = ${sql.str(details.email)}`)).toBe('1|Siem Reap');
});

test('409 IDEMPOTENCY_KEY_MISMATCH / ORDER_ALREADY_PAID are explained to the shopper', async ({ page }) => {
  const details = checkoutDetails(uniqueTag());
  await toCheckout(page, details);
  // These states are hard to reach by clicking (the key policy avoids the mismatch), so the API's real
  // error bodies are returned for one request each to check the UI explains them.
  const replies = [
    { code: 'IDEMPOTENCY_KEY_MISMATCH', message: 'Idempotency key was already used for a different checkout' },
    { code: 'ORDER_ALREADY_PAID', message: 'This order has already been paid' },
  ];
  const keys = [];
  await page.route('**/api/orders', async (route) => {
    if (route.request().method() !== 'POST') return route.continue();
    keys.push(JSON.parse(route.request().postData()).idempotencyKey);
    const reply = replies.shift();
    if (!reply) return route.continue();
    return route.fulfill({ status: 409, contentType: 'application/json', body: JSON.stringify({ status: 409, ...reply }) });
  });
  await page.getByRole('button', { name: 'Place order' }).click();
  await expect(page.getByTestId('order-error')).toContainText('Your checkout details changed since your last attempt');
  await page.getByRole('button', { name: 'Place order' }).click();
  await expect(page.getByTestId('order-error')).toContainText('already been paid');
  await expect(page).toHaveURL(/\/place-order$/); // no fake success
  expect(new Set(keys).size).toBe(2); // a fresh key after each of those errors
  expect(psql(`select count(*) from orders where email = ${sql.str(details.email)}`)).toBe('0');
});

test('429 TOO_MANY_GUEST_SESSIONS is shown to the shopper', async ({ page }) => {
  await page.route('**/api/guest-sessions', (route) => route.fulfill({
    status: 429,
    contentType: 'application/json',
    body: JSON.stringify({ status: 429, code: 'TOO_MANY_GUEST_SESSIONS', message: 'Too many guest sessions from this device. Please try again later or create an account' }),
  }));
  await page.goto(`/product/${product.id}`);
  await page.getByRole('button', { name: 'Size M', exact: true }).click();
  await page.getByRole('button', { name: 'Add to Cart', exact: true }).click();
  await expect(page.getByText(/Too many guest sessions from this device/)).toBeVisible();
  await expect(page.getByText(/Added to cart/)).toHaveCount(0);
});
