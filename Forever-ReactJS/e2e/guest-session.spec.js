// Guest shopping = an anonymous cart session (X-Guest-Session), never a login. Against the real API + Postgres:
// lazy session creation, persistence across reload / browser restart, expiry, guest order privacy (per-tab
// order-access token), shared devices, and the login/registration transition (no cart merge, no order
// attachment, guest session revoked). Every request is checked for mixed identities.
import {
  API, adminToken, apiCall, apiGuestSession, checkoutDetails, cleanupFixtureProduct, createFixtureProduct, deleteProduct, deleteTestOrders,
  deleteTestUser, expect, expectCleanIdentities, fillCheckout, instrument, latestOtp, psql, sql, test, tokenHash, uniqueTag,
} from './helpers.js';

let token;
let productA; // stays in the guest cart across the login transition
let productB; // ordered by the guest
const emails = []; // test accounts / order emails to clean up

test.beforeAll(async () => {
  token = await adminToken();
  const tag = uniqueTag();
  productA = await createFixtureProduct(token, { name: `E2E Guest A ${tag}`, price: '11.00', stock: 20 });
  productB = await createFixtureProduct(token, { name: `E2E Guest B ${tag}`, price: '7.00', stock: 20 });
});

test.afterAll(async () => {
  for (const email of emails) {
    deleteTestOrders(email);
    deleteTestUser(email);
  }
  for (const p of [productA, productB]) {
    if (!p) continue;
    await deleteProduct(token, p.id).catch(() => {});
    cleanupFixtureProduct(p.id);
  }
});

/** A separate browser "shopper" (own context), instrumented like the `page` fixture. */
async function shopper(browser, storageState) {
  const context = await browser.newContext(storageState ? { storageState } : {});
  const page = await context.newPage();
  const log = await instrument(page);
  const pageErrors = [];
  page.on('pageerror', (e) => pageErrors.push(e.message));
  const guestPosts = () => log.filter((r) => r.method === 'POST' && r.path === '/api/guest-sessions').length;
  const done = async () => {
    expect(pageErrors, 'uncaught page errors').toEqual([]);
    expectCleanIdentities(log);
    await context.close();
  };
  return { context, page, log, guestPosts, done };
}

const stored = (page) => page.evaluate(() => ({
  guest: JSON.parse(localStorage.getItem('forever.guestSession') || 'null'),
  tokens: localStorage.getItem('forever.tokens'),
}));

async function addFromDetail(page, product, size = 'S') {
  await page.goto(`/product/${product.id}`);
  await page.getByRole('button', { name: `Size ${size}`, exact: true }).click();
  const added = page.waitForResponse((r) => r.url().endsWith('/api/cart/items') && r.request().method() === 'POST');
  await page.getByRole('button', { name: 'Add to Cart', exact: true }).click();
  expect((await added).status()).toBe(200);
  await expect(page.getByText(`Added to cart (1 × size ${size})`).first()).toBeVisible();
}

async function expectAnonymousNavbar(page) {
  await expect(page.getByTestId('nav-login')).toBeVisible();
  await expect(page.getByRole('link', { name: 'Login' })).toBeVisible();
  await expect(page.getByTestId('profile-menu')).toHaveCount(0);
}

/** Checks out the whole cart with cash on delivery; resolves the order id. */
async function guestCodCheckout(page, details) {
  await page.goto('/cart');
  await page.getByRole('button', { name: /Checkout \d+ item/ }).click();
  await expect(page).toHaveURL(/\/place-order$/);
  await fillCheckout(page, details);
  const placed = page.waitForResponse((r) => r.url().endsWith('/api/orders') && r.request().method() === 'POST');
  await page.getByRole('button', { name: 'Place order' }).click();
  const order = await (await placed).json();
  expect(order).toMatchObject({ guest: true, userId: null });
  expect(order.guestAccessToken).toBeTruthy();
  await expect(page).toHaveURL(new RegExp(`/order-confirmation/${order.id}$`));
  return order;
}

test('guest cart: created lazily on first add, kept under its own key, survives reload and a browser restart', async ({ browser }) => {
  const a = await shopper(browser);
  // Browsing, the cart and checkout pages never start a session.
  for (const path of ['/', '/collection', `/product/${productA.id}`, '/cart', '/place-order']) {
    await a.page.goto(path);
    await a.page.waitForLoadState('networkidle');
  }
  await expect(a.page).toHaveURL(/\/cart$/); // checkout without a cart goes back to the (empty) cart
  await expect(a.page.getByText('Your cart is empty')).toBeVisible();
  expect(a.guestPosts(), 'no guest session just from visiting pages').toBe(0);
  expect(await stored(a.page)).toEqual({ guest: null, tokens: null });
  await expectAnonymousNavbar(a.page);

  // First add: exactly one session, stored as a guest session (not a login).
  await addFromDetail(a.page, productA, 'M');
  expect(a.guestPosts()).toBe(1);
  const s = await stored(a.page);
  expect(s.tokens, 'no login tokens').toBeNull();
  expect(s.guest.token).toBeTruthy();
  expect(psql(`select count(*) from guest_sessions where token_hash = ${sql.str(tokenHash(s.guest.token))}`)).toBe('1');
  await expectAnonymousNavbar(a.page);
  await expect(a.page.getByTestId('cart-count')).toHaveText('1');

  // Second add reuses the session.
  await addFromDetail(a.page, productB, 'S');
  expect(a.guestPosts()).toBe(1);

  // Reload: the cart comes back from the server.
  await a.page.reload();
  await expect(a.page.getByTestId('cart-count')).toHaveText('2');
  await a.page.goto('/cart');
  await expect(a.page.getByTestId('cart-line')).toHaveCount(2);
  await expectAnonymousNavbar(a.page);

  // "Close the browser and reopen it": a new context with the same persisted storage.
  const state = await a.context.storageState();
  await a.done();
  const b = await shopper(browser, state);
  await b.page.goto('/cart');
  await expect(b.page.getByTestId('cart-line')).toHaveCount(2);
  await expect(b.page.getByTestId('cart-line').filter({ hasText: productA.name })).toBeVisible();
  await expect(b.page.getByTestId('cart-count')).toHaveText('2');
  expect(b.guestPosts(), 'the reopened browser reuses its session').toBe(0);
  await expectAnonymousNavbar(b.page);
  // Account pages are still not reachable: they ask for a login.
  await b.page.goto('/order');
  await expect(b.page).toHaveURL(/\/login$/);
  await b.page.goto('/wishlist');
  await expect(b.page).toHaveURL(/\/login$/);
  // And the API refuses the guest session on them.
  const guest = (await stored(b.page)).guest.token;
  for (const path of ['/api/users/me', '/api/orders', '/api/wishlist', '/api/users/me/addresses']) {
    await expect(apiCall(path, { guest }), path).rejects.toThrow(/-> 403/);
  }
  await apiCall('/api/guest-sessions/current', { method: 'DELETE', guest });
  await b.done();
});

test('two quick adds share ONE new guest session', async ({ browser }) => {
  const a = await shopper(browser);
  await a.page.goto(`/product/${productA.id}`);
  await a.page.getByRole('button', { name: 'Size L', exact: true }).click();
  const sentTokens = [];
  a.page.on('request', (r) => r.url().endsWith('/api/cart/items') && sentTokens.push(r.headers()['x-guest-session']));
  // Two clicks in the same task, before React re-renders the button as disabled: two concurrent adds,
  // both needing a guest session that doesn't exist yet.
  await expect(a.page.getByRole('button', { name: 'Add to Cart', exact: true })).toBeEnabled();
  await a.page.evaluate(() => {
    const button = [...document.querySelectorAll('button')].find((b) => b.textContent.trim() === 'Add to Cart');
    button.click();
    button.click();
  });
  await expect.poll(() => sentTokens.length).toBe(2);
  await a.page.waitForLoadState('networkidle');
  expect(a.guestPosts(), 'concurrent adds share one session').toBe(1);
  const guest = (await stored(a.page)).guest.token;
  expect(sentTokens, 'both adds went to the same guest cart').toEqual([guest, guest]);
  const cart = await apiCall('/api/cart', { guest });
  expect(cart.items.map((i) => i.productId)).toEqual([productA.id]);
  await expect(a.page.getByTestId('cart-count')).toHaveText(String(cart.itemCount));
  await apiCall('/api/guest-sessions/current', { method: 'DELETE', guest });
  await a.done();
});

// Regression: concurrent POST /api/cart/items for a line the cart doesn't have yet used to give one 200 and one
// 500 (unique-index race on insert), losing the second quantity. Fixed in the API by serializing cart writes
// per shopper (ShopperLocks).
test('API: concurrent adds of the same new cart line both succeed', async () => {
  const { token: guest } = await apiGuestSession();
  const add = () => fetch(`${API}/api/cart/items`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-Guest-Session': guest },
    body: JSON.stringify({ productId: productA.id, size: 'S', quantity: 1 }),
  });
  const statuses = (await Promise.all([add(), add()])).map((r) => r.status);
  const cart = await apiCall('/api/cart', { guest });
  await apiCall('/api/guest-sessions/current', { method: 'DELETE', guest });
  expect(statuses).toEqual([200, 200]);
  expect(cart.items[0].quantity).toBe(2);
});

test('an expired guest session is dropped quietly; a new one only starts on the next add', async ({ browser }) => {
  const a = await shopper(browser);
  await a.page.goto('/about');
  await a.page.evaluate(() => localStorage.setItem('forever.guestSession',
    JSON.stringify({ token: 'no-such-session-token', expiresAt: '2030-01-01T00:00:00Z' })));
  const cartCall = a.page.waitForResponse((r) => r.url().endsWith('/api/cart'));
  await a.page.goto('/cart');
  const res = await cartCall;
  expect(res.status()).toBe(401);
  expect((await res.json()).code).toBe('GUEST_SESSION_EXPIRED');
  await expect(a.page.getByText('Your cart is empty')).toBeVisible();
  await expect.poll(async () => (await stored(a.page)).guest).toBeNull();
  await a.page.waitForLoadState('networkidle');
  expect(a.guestPosts(), 'no new session just because the old one expired').toBe(0);
  await expectAnonymousNavbar(a.page);

  await addFromDetail(a.page, productA);
  expect(a.guestPosts()).toBe(1);
  const guest = (await stored(a.page)).guest.token;
  expect(guest).not.toBe('no-such-session-token');
  await apiCall('/api/guest-sessions/current', { method: 'DELETE', guest });
  await a.done();
});

test('guest order confirmation is private to the tab that placed it', async ({ browser }) => {
  const details = checkoutDetails(uniqueTag());
  emails.push(details.email);
  const a = await shopper(browser);
  await addFromDetail(a.page, productB);
  const order = await guestCodCheckout(a.page, details);
  await expect(a.page.getByTestId('confirmation-customer')).toHaveText(`${details.firstName} ${details.lastName}`);
  await expect(a.page.getByTestId('confirmation-email')).toHaveText(details.email);
  await expectAnonymousNavbar(a.page);
  expect(psql(`select coalesce(user_id::text, 'null') from orders where id = ${order.id}`)).toBe('null');

  // Access token: sessionStorage of this tab only; not in localStorage, not in the URL.
  const access = await a.page.evaluate((id) => sessionStorage.getItem(`forever.orderAccess.${id}`), order.id);
  expect(access).toBe(order.guestAccessToken);
  expect(await a.page.evaluate(() => JSON.stringify(localStorage))).not.toContain(access);
  expect(a.page.url()).not.toContain(access);
  // Reloading the same tab keeps it viewable.
  await a.page.reload();
  await expect(a.page.getByTestId('confirmation-order-id')).toHaveText(`#${order.id}`);
  expect(a.log.some((r) => r.path === `/api/guest-orders/${order.id}` && r.orderAccess)).toBe(true);

  // API: the guest session can't read account orders; the guest-orders endpoint needs the right token.
  const guest = (await stored(a.page)).guest.token;
  await expect(apiCall(`/api/orders/${order.id}`, { guest })).rejects.toThrow(/-> 403/);
  await expect(apiCall(`/api/guest-orders/${order.id}`)).rejects.toThrow(/-> 404/);
  const wrong = await fetch(`${API}/api/guest-orders/${order.id}`, { headers: { 'X-Order-Access': 'wrong-token' } });
  expect(wrong.status).toBe(404);

  // Shared device: the shopper closes the tab; a new tab in the same browser can't see the confirmation.
  const url = a.page.url();
  const tab2 = await a.context.newPage();
  const tab2Calls = [];
  tab2.on('request', (r) => r.url().startsWith(API) && tab2Calls.push(new URL(r.url()).pathname));
  await a.page.close();
  await tab2.goto(url);
  await expect(tab2.getByTestId('confirmation-unavailable')).toBeVisible();
  await expect(tab2.getByText(`This confirmation is no longer available on this device`)).toBeVisible();
  await expect(tab2.getByText(`order #${order.id}`)).toBeVisible();
  await expect(tab2.getByTestId('confirmation-email')).toHaveCount(0);
  await tab2.waitForLoadState('networkidle');
  expect(tab2Calls.filter((p) => /\/api\/(guest-)?orders\//.test(p)), 'no order fetch at all').toEqual([]);

  // A different browser (fresh context) gets the same polite message and no order data.
  const c = await shopper(browser);
  await c.page.goto(url);
  await expect(c.page.getByTestId('confirmation-unavailable')).toBeVisible();
  await expect(c.page.getByText(details.email)).toHaveCount(0);
  await c.page.waitForLoadState('networkidle');
  expect(c.log.filter((r) => /\/api\/(guest-)?orders\//.test(r.path))).toEqual([]);
  await c.done();

  await apiCall('/api/guest-sessions/current', { method: 'DELETE', guest });
  await a.done();
});

test('registering / logging in never merges the guest cart or attaches guest orders; logout = fresh visitor', async ({ browser }) => {
  const tag = uniqueTag();
  const email = `e2e+acct${tag}@example.com`;
  const password = 'Passw0rd!e2e';
  emails.push(email);
  const a = await shopper(browser);

  // As a guest: order product B with email X, then put product A in the cart and keep it there.
  await addFromDetail(a.page, productB);
  const guestOrder = await guestCodCheckout(a.page, { ...checkoutDetails(tag), email });
  await addFromDetail(a.page, productA);
  await expect(a.page.getByTestId('cart-count')).toHaveText('1');
  const guestToken = (await stored(a.page)).guest.token;
  expect((await apiCall('/api/cart', { guest: guestToken })).items.map((i) => i.productId)).toEqual([productA.id]);

  // Register an account with the SAME email through the UI (code from Mailpit).
  await a.page.goto('/login');
  await a.page.getByText('Create Account').click();
  await a.page.getByPlaceholder('Name').fill('Sokha Account');
  await a.page.getByPlaceholder('Email').fill(email);
  await a.page.getByPlaceholder('Password', { exact: true }).fill(password);
  await a.page.getByRole('button', { name: 'Sign Up' }).click();
  await expect(a.page.getByText(`Enter the 6-digit code sent to`)).toBeVisible();
  await a.page.getByPlaceholder('000000').fill(await latestOtp(email));
  await a.page.getByRole('button', { name: 'Verify' }).click();
  await expect(a.page.getByTestId('profile-menu')).toBeVisible();

  // The guest session was ended server-side and forgotten locally.
  let s = await stored(a.page);
  expect(s.guest).toBeNull();
  expect(s.tokens).toBeTruthy();
  await expect.poll(() => psql(`select count(*) from guest_sessions where token_hash = ${sql.str(tokenHash(guestToken))}`)).toBe('0');
  await expect(apiCall('/api/cart', { guest: guestToken })).rejects.toThrow(/-> 401 .*GUEST_SESSION_EXPIRED/);
  // The account's cart does NOT contain product A; its orders do NOT contain the guest order.
  await expect(a.page.getByTestId('cart-count')).toHaveText('0');
  await a.page.goto('/cart');
  await expect(a.page.getByText('Your cart is empty')).toBeVisible();
  const accessToken = JSON.parse(s.tokens).accessToken;
  expect((await apiCall('/api/cart', { token: accessToken })).items).toEqual([]);
  await a.page.goto('/order');
  await expect(a.page.getByText('You have no orders yet.')).toBeVisible();
  await expect(a.page.getByText(`Order #${guestOrder.id}`)).toHaveCount(0);
  expect((await apiCall('/api/orders', { token: accessToken })).content).toEqual([]);
  await expect(apiCall(`/api/orders/${guestOrder.id}`, { token: accessToken })).rejects.toThrow(/-> (403|404)/);
  expect(psql(`select coalesce(user_id::text, 'null') from orders where id = ${guestOrder.id}`)).toBe('null');
  // Registered customers keep their prefill (profile name/email) at checkout — unlike guests.
  await addFromDetail(a.page, productB);
  await a.page.goto('/place-order');
  await expect(a.page.locator('input[name="email"]')).toHaveValue(email);

  // Log out: a fresh anonymous visitor with an empty cart and the Login link.
  await a.page.getByTestId('profile-menu').hover();
  await a.page.getByText('Logout', { exact: true }).click();
  await a.page.getByRole('button', { name: 'Log out' }).click();
  await expectAnonymousNavbar(a.page);
  await expect(a.page.getByTestId('cart-count')).toHaveText('0');
  expect(await stored(a.page)).toEqual({ guest: null, tokens: null });
  await a.page.goto('/cart');
  await expect(a.page.getByText('Your cart is empty')).toBeVisible();

  // Same again through the LOGIN form: a new guest cart, then log in -> account cart only, guest session ended.
  await addFromDetail(a.page, productA);
  const guest2 = (await stored(a.page)).guest.token;
  expect(guest2).not.toBe(guestToken);
  await a.page.goto('/login');
  await a.page.getByPlaceholder('Email').fill(email);
  await a.page.getByPlaceholder('Password', { exact: true }).fill(password);
  await a.page.getByRole('button', { name: 'Sign In' }).click();
  await expect(a.page.getByTestId('profile-menu')).toBeVisible();
  s = await stored(a.page);
  expect(s.guest).toBeNull();
  await expect.poll(() => psql(`select count(*) from guest_sessions where token_hash = ${sql.str(tokenHash(guest2))}`)).toBe('0');
  const cart = await apiCall('/api/cart', { token: JSON.parse(s.tokens).accessToken });
  expect(cart.items.map((i) => i.productId), 'only the account\'s own cart line (product B)').toEqual([productB.id]);
  await expect(a.page.getByTestId('cart-count')).toHaveText('1');
  await a.done();
});
