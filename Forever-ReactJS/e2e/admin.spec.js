// Admin panel through the UI: access control, product list columns, create (Image URL + stock + inactive in
// one request) / edit / delete, and the order list + expanded order details. Everything created is cleaned up.
import {
  ADMIN, adminToken, apiCall, apiGuestSession, apiGuestCodOrder, checkoutDetails, createFixtureProduct, deleteProduct,
  deleteTestOrders, expect, hardDeleteUnorderedProduct, test, uniqueTag, anyImageUrl,
} from './helpers.js';

let token;
const created = []; // product ids to clean up

test.beforeAll(async () => {
  token = await adminToken();
});

test.afterAll(async () => {
  for (const id of created) {
    await deleteProduct(token, id).catch(() => {});
    hardDeleteUnorderedProduct(id);
  }
});

async function loginAsAdmin(page) {
  await page.goto('/login');
  await page.getByPlaceholder('Email').fill(ADMIN.email);
  await page.getByPlaceholder('Password', { exact: true }).fill(ADMIN.password);
  await page.getByRole('button', { name: 'Sign In' }).click();
  await expect(page).not.toHaveURL(/\/login/);
}

test('visitors and guest sessions are denied /admin', async ({ page }) => {
  // No session at all.
  await page.goto('/admin/products');
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole('button', { name: '+ Add product' })).toHaveCount(0);

  // A guest cart session in storage is not a login: still no admin panel.
  const guest = await apiGuestSession();
  await page.evaluate((g) => localStorage.setItem('forever.guestSession', JSON.stringify(g)), guest);
  await page.goto('/admin/orders');
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole('heading', { name: 'Orders' })).toHaveCount(0);
  // And the API agrees.
  await expect(apiCall('/api/admin/orders', { guest: guest.token })).rejects.toThrow(/403/);
  await apiCall('/api/guest-sessions/current', { method: 'DELETE', guest: guest.token });
});

test('product list shows id/name/price/stock/status; create, edit and delete a product', async ({ page }) => {
  const imageUrl = await anyImageUrl();
  const name = `E2E Admin Jacket ${uniqueTag()}`;
  await loginAsAdmin(page);
  await page.goto('/admin/products');

  // Columns.
  for (const header of ['Product', 'Price', 'Stock', 'Visible', 'Actions']) {
    await expect(page.getByRole('columnheader', { name: header })).toBeVisible();
  }

  // Create: Image URL only (no upload), stock 7, inactive.
  await page.getByRole('button', { name: '+ Add product' }).click();
  const form = page.getByRole('dialog', { name: 'Add product' });
  await form.locator('#name').fill(name);
  await form.locator('#description').fill('Created by the admin E2E spec.');
  await form.getByRole('combobox', { name: 'Category', exact: true }).click();
  await page.getByRole('option', { name: 'Men', exact: true }).click();
  await form.getByRole('combobox', { name: 'Sub category' }).click();
  await page.getByRole('option', { name: 'Topwear', exact: true }).click();
  await form.locator('#price').fill('15.75');
  await form.getByRole('button', { name: 'S', exact: true }).click();
  await form.getByRole('button', { name: 'M', exact: true }).click();
  await form.getByLabel('Active (visible in the shop)').uncheck();
  await form.locator('#stock').fill('7');
  // Invalid URL first: the field shows an error and nothing is sent.
  await form.locator('#imageUrls').fill('ftp://nope.example.com/a.png');
  await form.getByRole('button', { name: 'Create product' }).click();
  await expect(form.locator('#imageUrls-error')).toContainText('http:// or https://');
  await form.locator('#imageUrls').fill(imageUrl);
  const createReq = page.waitForRequest((r) => r.url().endsWith('/api/admin/products') && r.method() === 'POST');
  await form.getByRole('button', { name: 'Create product' }).click();
  const body = (await createReq).postData() || '';
  expect(body).toContain('name="active"');
  expect(body).toContain('name="stock"');
  expect(body).toContain('name="imageUrls"');
  await expect(page.getByText('Product created')).toBeVisible();
  // No follow-up calls to the old separate endpoints.
  const [p] = (await apiCall(`/api/admin/products?q=${encodeURIComponent(name)}`, { token })).content;
  created.push(p.id);
  expect(p).toMatchObject({ name, active: false, stock: { S: 7, M: 7 }, images: [imageUrl] });
  expect(Number(p.price)).toBe(15.75);
  // Inactive: not in the shop.
  await expect(apiCall(`/api/products/${p.id}`)).rejects.toThrow(/404/);

  // The list row shows id / name / price / stock / status.
  await page.getByPlaceholder(/Search/).first().fill(name);
  const row = page.getByRole('row').filter({ hasText: name });
  await expect(row).toContainText(`#${p.id}`);
  await expect(row).toContainText('$15.75');
  await expect(row.getByRole('cell').nth(3)).toHaveText(/^14/); // 7 + 7
  await expect(row.getByRole('switch', { name: `Show ${name}` })).toHaveAttribute('aria-checked', 'false');

  // Edit: current per-size stock is shown; leave stock blank (kept), change price, make it active.
  await row.getByRole('button', { name: 'Edit' }).click();
  const edit = page.getByRole('dialog', { name: `Edit product #${p.id}` });
  await expect(edit.getByTestId('current-stock')).toContainText('S: 7');
  await expect(edit.getByTestId('current-stock')).toContainText('M: 7');
  await edit.locator('#price').fill('16.25');
  await edit.getByLabel('Active (visible in the shop)').check();
  const updateReq = page.waitForRequest((r) => r.url().endsWith(`/api/admin/products/${p.id}`) && r.method() === 'PUT');
  await edit.getByRole('button', { name: 'Save changes' }).click();
  const updateBody = (await updateReq).postData() || '';
  expect(updateBody).not.toContain('name="stock"'); // blank = keep per-size stock
  expect(updateBody).not.toContain('name="imageUrls"');
  await expect(page.getByText('Product updated')).toBeVisible();
  const afterEdit = await apiCall(`/api/admin/products/${p.id}`, { token });
  expect(afterEdit).toMatchObject({ active: true, stock: { S: 7, M: 7 }, images: [imageUrl] });
  expect(Number(afterEdit.price)).toBe(16.25);
  expect((await apiCall(`/api/products/${p.id}`)).inStock).toBe(true);

  // Delete (the API hides it from the shop).
  await expect(row.getByRole('switch', { name: `Hide ${name}` })).toHaveAttribute('aria-checked', 'true');
  await row.getByRole('button', { name: 'Delete' }).click();
  await page.getByRole('button', { name: 'Delete product' }).click();
  await expect(page.getByText(`"${name}" deleted`)).toBeVisible();
  await expect(apiCall(`/api/products/${p.id}`)).rejects.toThrow(/404/);
  // Cleanup: no order uses it, so remove it completely.
  expect(hardDeleteUnorderedProduct(p.id)).toBe(true);
  created.splice(created.indexOf(p.id), 1);
});

test('order history shows a guest order; details show items, qty, unit price, subtotal and address', async ({ page }) => {
  const product = await createFixtureProduct(token, { name: `E2E Order Tee ${uniqueTag()}`, price: '9.99', stock: 10 });
  created.push(product.id);
  const details = checkoutDetails(uniqueTag());
  const order = await apiGuestCodOrder({ productId: product.id, size: 'M', quantity: 3, address: details });

  await loginAsAdmin(page);
  await page.goto('/admin/orders');
  await page.getByPlaceholder('Order #, customer name, email or phone').fill(details.email);
  const row = page.getByRole('row').filter({ hasText: `#${order.id}` });
  await expect(row).toBeVisible();
  await expect(row).toContainText(`${details.firstName} ${details.lastName}`);
  await expect(row).toContainText(details.phone);
  await expect(row).toContainText(`$${Number(order.total).toFixed(2)}`);
  await expect(row).toContainText(new Date(order.createdAt).getFullYear().toString()); // date shown

  await row.click();
  const items = page.getByTestId(`order-${order.id}-items`);
  await expect(items).toBeVisible();
  for (const header of ['Item', 'Qty', 'Unit price', 'Subtotal']) {
    await expect(items.getByRole('columnheader', { name: header, exact: true })).toBeVisible();
  }
  const itemRow = items.locator('tbody tr');
  await expect(itemRow).toHaveCount(1);
  await expect(itemRow).toContainText(product.name);
  await expect(itemRow).toContainText('Size M');
  await expect(itemRow.getByRole('cell').nth(1)).toHaveText('3');
  await expect(itemRow.getByRole('cell').nth(2)).toHaveText('$9.99');
  await expect(itemRow.getByRole('cell').nth(3)).toHaveText('$29.97');
  const details_ = page.getByRole('row').filter({ has: items });
  await expect(details_).toContainText(details.street);
  await expect(details_).toContainText(`${details.city}, ${details.state} ${details.zipcode}`);
  await expect(details_).toContainText(details.country);

  // The product has an order now, so it is only hidden (kept for the order record).
  await deleteProduct(token, product.id);
  // Clean-up: drop the test guest order, then the product itself (afterAll hard-deletes it).
  deleteTestOrders(details.email);
});
