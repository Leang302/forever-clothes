// SSR checks for the public routes (/, /collection, /product/:id): raw HTML content + meta tags, clean
// hydration (no React hydration warnings/errors in the console), no duplicate fetch of the data the server
// already embedded, working controls after hydration, and absolute share links.
import { ADMIN, API, apiCall, apiGuestSession, expect, test } from './helpers.js';

const HYDRATION_PROBLEM = /hydrat|did not match|server html|server rendered|Minified React error #(418|419|421|422|423|425)/i;

let product; // an in-stock product with a description

test.beforeAll(async () => {
  const latest = await apiCall('/api/products/latest?limit=10');
  product = latest.find((p) => p.inStock && p.description) || latest[0];
});

/** Records storefront → API requests (path + query) made by the page. */
function recordApiRequests(page) {
  const seen = [];
  page.on('request', (r) => {
    if (r.url().startsWith(API)) {
      const u = new URL(r.url());
      seen.push(`${r.method()} ${u.pathname}${u.search}`);
    }
  });
  return seen;
}

async function expectCleanHydration(page, consoleProblems) {
  expect(await page.evaluate(() => window.__SSR_DATA__ !== null), 'page was server-rendered with data').toBe(true);
  const hydrationIssues = consoleProblems.filter((m) => HYDRATION_PROBLEM.test(m));
  expect(hydrationIssues, 'hydration warnings/errors in the console').toEqual([]);
  // Nothing else should be logged either; keep the full list visible on failure.
  expect(consoleProblems, 'console errors/warnings').toEqual([]);
}

test.describe('raw server HTML (curl-equivalent, no JavaScript)', () => {
  test('product page HTML has name, price, description and SEO/share meta', async ({ request, baseURL }) => {
    const res = await request.get(`/product/${product.id}`);
    expect(res.status()).toBe(200);
    const html = await res.text();
    const price = Number(product.price).toFixed(2);
    expect(html).toContain(`>${product.name}</h1>`);
    expect(html).toContain(product.description);
    expect(html).toMatch(new RegExp(`\\$(<!-- -->)?${Number(product.price)}`)); // rendered price
    expect(html).toContain(`<title>${product.name} — $${price} | Forever</title>`);
    expect(html).toMatch(/<meta name="description" content="[^"]+"/);
    expect(html).toContain(`<meta property="og:title" content="${product.name} — $${price} | Forever" />`);
    expect(html).toMatch(/<meta property="og:description" content="[^"]+"/);
    expect(html).toContain(`<meta property="og:type" content="product" />`);
    expect(html).toContain(`<meta property="og:url" content="${baseURL}/product/${product.id}" />`);
    expect(html).toContain(`<meta property="og:image" content="${product.images[0]}" />`);
    expect(product.images[0]).toMatch(/^https?:\/\//); // absolute
    expect(html).toContain('<meta name="twitter:card" content="summary_large_image" />');
    // Share links are absolute in the server HTML already.
    expect(html).toContain(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(`${baseURL}/product/${product.id}`)}`);
  });

  test('og:url honours X-Forwarded-Proto/Host behind a proxy', async ({ request }) => {
    const html = await (await request.get(`/product/${product.id}`, {
      headers: { 'X-Forwarded-Proto': 'https', 'X-Forwarded-Host': 'shop.example.com' },
    })).text();
    expect(html).toContain(`<meta property="og:url" content="https://shop.example.com/product/${product.id}" />`);
    expect(html).toContain(encodeURIComponent(`https://shop.example.com/product/${product.id}`));
  });

  test('home and collection HTML have product names/prices and default meta', async ({ request }) => {
    const latest = await apiCall('/api/products/latest?limit=10');
    const home = await (await request.get('/')).text();
    expect(home).toContain('<title>Forever — Latest fashion</title>');
    expect(home).toMatch(/<meta property="og:type" content="website" \/>/);
    expect(home).toContain(`>${latest[0].name}</p>`);
    expect(home).toMatch(new RegExp(`\\$(<!-- -->)?${Number(latest[0].price)}<`));

    const page0 = await apiCall('/api/products?page=0&size=20&sort=relevant');
    const collection = await (await request.get('/collection')).text();
    expect(collection).toContain('<title>All collections | Forever</title>');
    expect(collection).toContain(`>${page0.content[0].name}</p>`);
    expect(collection).toContain(`${page0.totalElements}<!-- --> <!-- -->products`);
  });

  test('unknown product returns 404; session pages are client-rendered shells', async ({ request }) => {
    expect((await request.get('/product/99999999')).status()).toBe(404);
    for (const path of ['/cart', '/place-order', '/order-confirmation/1', '/admin', '/login']) {
      const html = await (await request.get(path)).text();
      expect(html, path).toContain('<div id="root"></div>');
      expect(html, path).toContain('window.__SSR_DATA__ = null');
    }
  });
});

test.describe('hydration in a real browser', () => {
  test('/ hydrates cleanly, does not refetch latest/bestsellers, quick-add opens', async ({ page, consoleProblems }) => {
    const requests = recordApiRequests(page);
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    await expectCleanHydration(page, consoleProblems);
    expect(requests.filter((r) => /\/api\/products\/(latest|bestsellers)/.test(r))).toEqual([]);
    expect(requests.filter((r) => r.includes('/api/guest-sessions'))).toEqual([]);

    const card = page.getByTestId('product-card').filter({ has: page.getByRole('button', { name: /^Add .* to cart$/ }) }).first();
    await card.getByRole('button', { name: /^Add .* to cart$/ }).click();
    await expect(card.getByRole('dialog')).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(card.getByRole('dialog')).toBeHidden();
    expect(consoleProblems).toEqual([]);
  });

  test('/collection hydrates cleanly, does not refetch products, filters work', async ({ page, consoleProblems }) => {
    const requests = recordApiRequests(page);
    await page.goto('/collection');
    await page.waitForLoadState('networkidle');
    await expectCleanHydration(page, consoleProblems);
    expect(requests.filter((r) => /^GET \/api\/products\?/.test(r))).toEqual([]);

    const refetch = page.waitForRequest((r) => r.url().includes('/api/products?') && r.url().includes('category=Men'));
    await page.getByRole('checkbox', { name: 'Men', exact: true }).check();
    await refetch;
    await expect(page).toHaveURL(/category=Men/);
    expect(consoleProblems).toEqual([]);
  });

  test('/product/:id hydrates cleanly, does not refetch the product, size + share links work', async ({ page, consoleProblems, baseURL }) => {
    const requests = recordApiRequests(page);
    await page.goto(`/product/${product.id}`);
    await page.waitForLoadState('networkidle');
    await expectCleanHydration(page, consoleProblems);
    expect(requests.filter((r) => r === `GET /api/products/${product.id}`)).toEqual([]);

    const size = product.sizes.find((s) => product.stock[s] > 0);
    await page.getByRole('button', { name: `Size ${size}`, exact: true }).click();
    await expect(page.getByRole('button', { name: `Size ${size}`, exact: true })).toHaveAttribute('aria-pressed', 'true');
    await expect(page.getByTestId('stock-status')).toContainText(`size ${size}`);

    const productUrl = `${baseURL}/product/${product.id}`;
    await expect(page.getByRole('link', { name: 'Share on Facebook' }))
      .toHaveAttribute('href', `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(productUrl)}`);
    await expect(page.getByRole('link', { name: 'Share on Telegram' }))
      .toHaveAttribute('href', `https://t.me/share/url?url=${encodeURIComponent(productUrl)}&text=${encodeURIComponent(product.name)}`);
    expect(consoleProblems).toEqual([]);
  });

  test('hydrates cleanly when the browser holds a signed-in session the server cannot see', async ({ page, consoleProblems }) => {
    const login = await apiCall('/api/auth/login', { method: 'POST', body: ADMIN });
    await page.goto('/about'); // any page on the origin, to write localStorage
    await page.evaluate((t) => localStorage.setItem('forever.tokens', JSON.stringify(t)),
      { accessToken: login.accessToken, refreshToken: login.refreshToken });
    for (const path of ['/', '/collection', `/product/${product.id}`]) {
      await page.goto(path);
      await page.waitForLoadState('networkidle');
      await expectCleanHydration(page, consoleProblems);
    }
    // After hydration the session is restored client-side (admin: shopping buttons are hidden).
    await expect(page.getByRole('button', { name: 'Add to Cart', exact: true })).toHaveCount(0);
  });

  test('hydrates cleanly with a guest cart session the server cannot see (still not logged in)', async ({ page, consoleProblems }) => {
    const guest = await apiGuestSession();
    await apiCall('/api/cart/items', { method: 'POST', guest: guest.token, body: { productId: product.id, size: product.sizes.find((s) => product.stock[s] > 0), quantity: 1 } });
    await page.goto('/about');
    await page.evaluate((g) => localStorage.setItem('forever.guestSession', JSON.stringify(g)), guest);
    for (const path of ['/', '/collection', `/product/${product.id}`]) {
      await page.goto(path);
      await page.waitForLoadState('networkidle');
      await expectCleanHydration(page, consoleProblems);
      // The guest cart is loaded client-side after hydration; the navbar still offers Login.
      await expect(page.getByTestId('cart-count')).toHaveText('1');
      await expect(page.getByTestId('nav-login')).toBeVisible();
    }
    await apiCall('/api/guest-sessions/current', { method: 'DELETE', guest: guest.token });
  });

  test('client-side navigation back to / fetches fresh data (SSR snapshot is used once)', async ({ page }) => {
    await page.goto(`/product/${product.id}`);
    await page.waitForLoadState('networkidle');
    const latestFetch = page.waitForRequest((r) => r.url().includes('/api/products/latest'));
    await page.getByRole('link', { name: 'HOME' }).first().click();
    await latestFetch;
  });
});
