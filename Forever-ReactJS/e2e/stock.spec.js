// Stock behaviour with real per-size stock changed through the admin API (and restored afterwards).
import {
  adminToken, apiCall, createFixtureProduct, deleteProduct, expect, hardDeleteUnorderedProduct, setStock, test, uniqueTag,
} from './helpers.js';

let token;
let product; // fixture: sizes S/M/L, 10 each
let original; // { size: stock } as created, restored after each test

test.beforeAll(async () => {
  token = await adminToken();
  product = await createFixtureProduct(token, { name: `E2E Stock Tee ${uniqueTag()}`, stock: 10 });
  original = { ...product.stock };
});

test.afterEach(async () => {
  for (const [size, stock] of Object.entries(original)) await setStock(token, product.id, size, stock);
  const now = await apiCall(`/api/products/${product.id}`);
  expect(now.stock).toEqual(original); // restored
});

test.afterAll(async () => {
  if (!product) return;
  await deleteProduct(token, product.id);
  hardDeleteUnorderedProduct(product.id); // never ordered here, so remove it completely
});

const card = (page) => page.locator(`[data-testid="product-card"][data-product-id="${product.id}"]`).first();

test('a size with 0 stock is disabled on the detail page and in the listing picker', async ({ page }) => {
  await setStock(token, product.id, 'M', 0);

  await page.goto(`/product/${product.id}`);
  await expect(page.getByTestId('stock-status')).toContainText('In stock'); // other sizes still have stock
  await expect(page.getByRole('button', { name: 'Size M (out of stock)' })).toBeDisabled();
  await expect(page.getByRole('button', { name: 'Size S', exact: true })).toBeEnabled();
  await page.getByRole('button', { name: 'Size S', exact: true }).click();
  await expect(page.getByTestId('stock-status')).toContainText('In stock');

  await page.goto('/');
  await card(page).getByRole('button', { name: `Add ${product.name} to cart` }).click();
  const panel = card(page).getByRole('dialog');
  await expect(panel.getByRole('button', { name: 'Size M (out of stock)' })).toBeDisabled();
  await expect(panel.getByRole('button', { name: 'Size L', exact: true })).toBeEnabled();
});

test('low stock shows "Only N left" and caps the quantity stepper', async ({ page }) => {
  await setStock(token, product.id, 'L', 3);
  await page.goto(`/product/${product.id}`);
  await page.getByRole('button', { name: 'Size L', exact: true }).click();
  await expect(page.getByTestId('stock-status')).toContainText('Only 3 left');
  const plus = page.getByRole('button', { name: 'Increase quantity' });
  await plus.click();
  await plus.click();
  await expect(page.getByLabel('Quantity', { exact: true })).toHaveValue('3');
  await expect(plus).toBeDisabled();
  await page.getByLabel('Quantity', { exact: true }).fill('50');
  await expect(page.getByLabel('Quantity', { exact: true })).toHaveValue('3');
});

test('fully out of stock: card says Out of stock, detail page cannot add', async ({ page }) => {
  for (const size of Object.keys(original)) await setStock(token, product.id, size, 0);
  const now = await apiCall(`/api/products/${product.id}`);
  expect(now.inStock).toBe(false);
  expect(now.active).toBe(true); // `active` is not a stock signal

  await page.goto('/');
  await expect(card(page).getByRole('button', { name: `${product.name} is out of stock` })).toBeDisabled();
  await expect(card(page).getByText('Out of stock').first()).toBeVisible();

  await page.goto(`/product/${product.id}`);
  await expect(page.getByTestId('stock-status')).toContainText('Out of stock');
  await expect(page.getByRole('button', { name: 'Out of stock', exact: true })).toBeDisabled();
});

test('stock dropping underneath: 409 message on add, cart line flagged and checkout blocked', async ({ page }) => {
  // Detail page loaded while S has 10, then stock drops to 1 before the shopper adds 3.
  await page.goto(`/product/${product.id}`);
  await page.getByRole('button', { name: 'Size S', exact: true }).click();
  await page.getByLabel('Quantity', { exact: true }).fill('3');
  await setStock(token, product.id, 'S', 1);
  const add = page.waitForResponse((r) => r.url().endsWith('/api/cart/items') && r.request().method() === 'POST');
  await page.getByRole('button', { name: 'Add to Cart', exact: true }).click();
  const res = await add;
  expect(res.status()).toBe(409);
  expect((await res.json()).code).toBe('OUT_OF_STOCK');
  await expect(page.getByText(/Only 1 left of .* in size S/)).toBeVisible(); // the server's message
  await expect(page.getByTestId('stock-status')).toContainText('Only 1 left'); // refreshed from the API
  await expect(page.getByLabel('Quantity', { exact: true })).toHaveValue('1');

  // With 5 in stock add 4, then stock drops to 2 while they sit in the cart.
  await setStock(token, product.id, 'S', 5);
  await page.reload(); // fresh stock (5)
  await page.getByRole('button', { name: 'Size S', exact: true }).click();
  await page.getByLabel('Quantity', { exact: true }).fill('4');
  await page.getByRole('button', { name: 'Add to Cart', exact: true }).click();
  await expect(page.getByText('Added to cart (4 × size S)')).toBeVisible();
  await setStock(token, product.id, 'S', 2);

  await page.goto('/cart');
  const line = page.getByTestId('cart-line').filter({ hasText: product.name });
  await expect(line.getByTestId('line-stock-problem')).toContainText('Only 2 left in size S');
  await expect(page.getByRole('button', { name: /Checkout 1 item/ })).toBeDisabled();
  await line.getByRole('button', { name: 'Set to 2' }).click();
  await expect(line.getByTestId('line-stock-problem')).toHaveCount(0);
  await expect(line.getByTestId('line-subtotal')).toContainText('2 ×');
  await expect(page.getByRole('button', { name: /Checkout 1 item/ })).toBeEnabled();

  // Typing more than the stock in the cart is clamped to it.
  await line.getByLabel(`Quantity of ${product.name} (size S)`).fill('9');
  await expect(line.getByLabel(`Quantity of ${product.name} (size S)`)).toHaveValue('2');
});
