// Guest shopper flows against the real API + Postgres + fake Bakong: KHQR checkout (pending -> paid),
// cash on delivery, and a double-clicked "Place order".
import {
  adminToken, checkoutDetails, cleanupFixtureProduct, createFixtureProduct, deleteProduct, expect, fillCheckout, payQr, psql, sql,
  test, uniqueTag,
} from './helpers.js';

const money = (v) => `$${Number(v).toFixed(2)}`;

let token;
let product; // fixture: sizes S/M/L, 10 each, $12.50

test.beforeAll(async () => {
  token = await adminToken();
  product = await createFixtureProduct(token, { name: `E2E Guest Tee ${uniqueTag()}`, price: '12.50', stock: 10 });
});

test.afterAll(async () => {
  if (!product) return;
  await deleteProduct(token, product.id);
  cleanupFixtureProduct(product.id);
});

/** Adds `qty` of `size` from the product's card on the home page (quick-add panel). */
async function quickAddFromHome(page, { size, qty }) {
  await page.goto('/');
  const card = page.locator(`[data-testid="product-card"][data-product-id="${product.id}"]`).first();
  await expect(card).toBeVisible();
  await card.getByRole('button', { name: `Add ${product.name} to cart` }).click();
  const panel = card.getByRole('dialog', { name: `Add ${product.name} to cart` });
  await expect(panel).toBeVisible();
  await panel.getByRole('button', { name: `Size ${size}`, exact: true }).click();
  for (let i = 1; i < qty; i += 1) await panel.getByRole('button', { name: 'Increase quantity' }).click();
  await expect(panel.getByLabel('Quantity', { exact: true })).toHaveValue(String(qty));
  const added = page.waitForResponse((r) => r.url().endsWith('/api/cart/items') && r.request().method() === 'POST');
  await panel.getByRole('button', { name: 'Add to cart' }).click();
  expect((await added).status()).toBe(200);
  await expect(page.getByText(`Added to cart (${qty} × size ${size})`)).toBeVisible();
  await expect(panel).toBeHidden();
}

test('guest: listing quick-add -> detail -> cart edits -> KHQR pending -> paid -> confirmation + DB', async ({ page }) => {
  const details = checkoutDetails(uniqueTag());

  // Fresh context, no storage: no guest session is created just by browsing.
  const guestCalls = [];
  page.on('request', (r) => r.url().endsWith('/api/guest-sessions') && r.method() === 'POST' && guestCalls.push(r.url()));
  await page.goto('/');
  await page.goto('/collection');
  expect(guestCalls, 'browsing must not mint guest sessions').toHaveLength(0);

  // 1) Add to cart from the listing card: size M, qty 2. The guest cart session is created lazily here.
  await quickAddFromHome(page, { size: 'M', qty: 2 });
  expect(guestCalls).toHaveLength(1);
  await expect(page.getByTestId('cart-count')).toHaveText('2');

  // 2) The card still links to the product detail page.
  await page.locator(`[data-testid="product-card"][data-product-id="${product.id}"] a`).first().click();
  await expect(page).toHaveURL(new RegExp(`/product/${product.id}$`));
  await expect(page.getByRole('heading', { name: product.name })).toBeVisible();
  await page.getByRole('button', { name: 'Size L', exact: true }).click();
  await expect(page.getByTestId('stock-status')).toContainText('In stock');
  await page.getByRole('button', { name: 'Increase quantity' }).click();
  await expect(page.getByLabel('Quantity', { exact: true })).toHaveValue('2');
  await page.getByRole('button', { name: 'Add to Cart', exact: true }).click();
  await expect(page.getByText('Added to cart (2 × size L)')).toBeVisible();
  await expect(page.getByTestId('cart-count')).toHaveText('4');

  // 3) Cart: two lines with unit price + explicit line subtotal; update qty, remove a line.
  await page.getByRole('link', { name: 'Cart' }).click();
  await expect(page).toHaveURL(/\/cart$/);
  const lines = page.getByTestId('cart-line');
  await expect(lines).toHaveCount(2);
  const lineM = lines.filter({ hasText: product.name }).filter({ has: page.getByText('M', { exact: true }) });
  await expect(lineM.getByTestId('line-unit-price')).toContainText('$12.50');
  await expect(lineM.getByTestId('line-subtotal')).toContainText('$25.00');
  const updated = page.waitForResponse((r) => r.url().endsWith('/api/cart/items') && r.request().method() === 'PUT');
  await lineM.getByLabel(`Quantity of ${product.name} (size M)`).fill('3');
  expect((await updated).status()).toBe(200);
  await expect(lineM.getByTestId('line-subtotal')).toContainText('$37.50');
  await page.getByRole('button', { name: `Remove ${product.name} (size L)` }).click();
  await expect(lines).toHaveCount(1);
  await expect(page.getByTestId('cart-count')).toHaveText('3');

  // 4) Checkout: a validation error shows next to its field.
  await page.getByRole('button', { name: /Checkout 1 item/ }).click();
  await expect(page).toHaveURL(/\/place-order$/);
  // A guest gets an EMPTY form: no generated name/email, no saved-address UI.
  for (const name of Object.keys(details)) await expect(page.locator(`input[name="${name}"]`)).toHaveValue('');
  await expect(page.getByText('Saved addresses')).toHaveCount(0);
  await expect(page.getByText('Save this address for next time')).toHaveCount(0);
  // Submitting the empty form shows field-level errors for the required details.
  await page.getByRole('button', { name: 'Place order' }).click();
  for (const name of ['firstName', 'lastName', 'email', 'street', 'city', 'state', 'zipcode', 'country', 'phone']) {
    await expect(page.locator(`#checkout-${name}-error`)).toBeVisible();
  }
  await fillCheckout(page, { ...details, email: 'not-an-email' });
  await page.getByRole('button', { name: /KHQR/ }).first().click();
  await page.getByRole('button', { name: 'Pay with KHQR' }).click();
  const emailError = page.locator('#checkout-email-error');
  await expect(emailError).toBeVisible();
  await expect(page.locator('input[name="email"]')).toHaveAttribute('aria-invalid', 'true');
  await expect(page.locator('input[name="email"]')).toHaveAttribute('aria-describedby', 'checkout-email-error');
  await page.locator('input[name="email"]').fill(details.email);
  await expect(emailError).toBeHidden();

  // 5) KHQR: the QR is shown; while unpaid, polling says pending and NO success is shown.
  const checkoutRes = page.waitForResponse((r) => r.url().endsWith('/api/khqr/checkout'));
  await page.getByRole('button', { name: 'Pay with KHQR' }).click();
  const khqr = await (await checkoutRes).json();
  expect(khqr.qrString).toBeTruthy();
  expect(khqr.guestAccessToken, 'a guest KHQR checkout returns its order-access token').toBeTruthy();
  // The token is kept per tab (sessionStorage), never in localStorage or the URL.
  expect(await page.evaluate((id) => sessionStorage.getItem(`forever.orderAccess.${id}`), khqr.orderId)).toBe(khqr.guestAccessToken);
  expect(await page.evaluate(() => JSON.stringify(localStorage))).not.toContain(khqr.guestAccessToken);
  await expect(page.getByRole('dialog', { name: 'Scan to pay' })).toBeVisible();
  await expect(page.getByAltText('KHQR payment code')).toBeVisible();

  const firstVerify = await page.waitForResponse((r) => r.url().endsWith(`/api/guest-orders/${khqr.orderId}/khqr/verify`), { timeout: 15_000 });
  expect(await firstVerify.json()).toMatchObject({ paid: false, status: 'PENDING' });
  await expect(page.getByTestId('khqr-last-check')).toContainText('Not paid yet');
  await expect(page.getByText('Payment received')).toHaveCount(0);
  await expect(page).toHaveURL(/\/place-order$/);
  expect(psql(`select paid, status from orders where id = ${khqr.orderId}`)).toBe('f|PAYMENT_PENDING');

  // 6) Simulate the customer paying exactly the shown amount; the app's normal polling flips to PAID.
  const expectedTotal = Number(khqr.amount);
  await payQr(khqr.qrString, expectedTotal);
  await expect(page).toHaveURL(new RegExp(`/order-confirmation/${khqr.orderId}$`), { timeout: 20_000 });
  expect(page.url()).not.toContain(khqr.guestAccessToken);

  // 7) Confirmation shows the server's view of the order.
  await expect(page.getByTestId('confirmation-title')).toHaveText('Thank you — your order is paid');
  await expect(page.getByTestId('confirmation-payment')).toHaveText('Paid (KHQR)');
  await expect(page.getByTestId('confirmation-order-id')).toHaveText(`#${khqr.orderId}`);
  await expect(page.getByTestId('confirmation-customer')).toHaveText(`${details.firstName} ${details.lastName}`);
  await expect(page.getByTestId('confirmation-email')).toHaveText(details.email);
  await expect(page.getByTestId('confirmation-phone')).toHaveText(details.phone);
  await expect(page.getByTestId('confirmation-total')).toHaveText(money(expectedTotal));
  const itemRow = page.getByTestId('confirmation-items').locator('tbody tr');
  await expect(itemRow).toHaveCount(1);
  await expect(itemRow).toContainText(product.name);
  await expect(itemRow.locator('td').nth(1)).toHaveText('M');
  await expect(itemRow.locator('td').nth(2)).toHaveText('3');
  await expect(itemRow.locator('td').nth(4)).toHaveText('$37.50');

  // 8) Database: the order and its items exist, the order is paid, and it belongs to no user account.
  const row = psql(`select paid, status, payment_method, total, email, phone, coalesce(user_id::text, 'null') from orders where id = ${khqr.orderId}`);
  expect(row).toBe(`t|ORDER_PLACED|KHQR|${expectedTotal.toFixed(2)}|${details.email}|${details.phone}|null`);
  // The shopper was never logged in.
  expect(await page.evaluate(() => localStorage.getItem('forever.tokens'))).toBeNull();
  await expect(page.getByTestId('nav-login')).toBeVisible();
  expect(psql(`select product_id, size, quantity from order_items where order_id = ${khqr.orderId}`)).toBe(`${product.id}|M|3`);
});

async function addOneAndCheckout(page, details, size = 'S') {
  await page.goto(`/product/${product.id}`);
  await page.getByRole('button', { name: `Size ${size}`, exact: true }).click();
  await page.getByRole('button', { name: 'Add to Cart', exact: true }).click();
  await expect(page.getByText(`Added to cart (1 × size ${size})`)).toBeVisible();
  await page.goto('/cart');
  await page.getByRole('button', { name: /Checkout 1 item/ }).click();
  await expect(page).toHaveURL(/\/place-order$/);
  await fillCheckout(page, details);
}

test('guest: cash on delivery -> confirmation says pay on delivery, not paid', async ({ page }) => {
  const details = checkoutDetails(uniqueTag());
  await addOneAndCheckout(page, details);
  await page.getByRole('button', { name: /Cash on Delivery/ }).click();
  await page.getByRole('button', { name: 'Place order' }).click();
  await expect(page).toHaveURL(/\/order-confirmation\/\d+$/);
  const orderId = page.url().split('/').pop();
  await expect(page.getByTestId('confirmation-title')).toHaveText('Order placed — pay on delivery');
  await expect(page.getByTestId('confirmation-payment')).toContainText('Cash on delivery');
  await expect(page.getByTestId('confirmation-payment')).not.toContainText('Paid');
  await expect(page.getByText('Thank you — your order is paid')).toHaveCount(0);
  await expect(page.getByTestId('confirmation-items')).toContainText(product.name);
  // The typed details are what the confirmation shows.
  await expect(page.getByTestId('confirmation-customer')).toHaveText(`${details.firstName} ${details.lastName}`);
  await expect(page.getByTestId('confirmation-email')).toHaveText(details.email);
  await expect(page.getByTestId('confirmation-phone')).toHaveText(details.phone);
  await expect(page.getByRole('link', { name: 'View order' })).toHaveCount(0); // no account order page for guests
  expect(psql(`select paid, payment_method, status, coalesce(user_id::text, 'null') from orders where id = ${orderId}`))
    .toBe('f|COD|ORDER_PLACED|null');
});

test('guest: double-clicking Place order creates exactly one order', async ({ page }) => {
  const details = checkoutDetails(uniqueTag());
  await addOneAndCheckout(page, details);
  const orderPosts = [];
  page.on('request', (r) => r.url().endsWith('/api/orders') && r.method() === 'POST' && orderPosts.push(r));
  await page.getByRole('button', { name: 'Place order' }).dblclick();
  await expect(page).toHaveURL(/\/order-confirmation\/\d+$/);
  expect(psql(`select count(*) from orders where email = ${sql.str(details.email)}`)).toBe('1');
  expect(orderPosts.length).toBeLessThanOrEqual(2); // even if two requests left, the idempotency key dedupes
});
