// Server entry for SSR: fetches the data a public page (Home / Collection / Product) needs straight from
// the API, renders the app to an HTML string at the given URL, and hands back the HTML, the data (embedded
// as `window.__SSR_DATA__` for entry-client.jsx to hydrate from — no refetch, no flash) and the page's
// <head> tags (title, description, Open Graph / Twitter card) to server.js.
//
// Scope: only Home ("/"), Collection ("/collection") and Product ("/product/:id") are server-rendered with
// data — the public, SEO-relevant pages. Everything else (cart, checkout, order confirmation, admin,
// profile, login, ...) depends on the shopper's session, whose tokens live in the browser's localStorage
// and are never sent to this server, so it can't render them with real content. Those URLs get the plain
// shell and App renders them client-side (createRoot), exactly like a CSR app.
import ReactDOMServer from 'react-dom/server';
import { StaticRouter } from 'react-router-dom/server';
import App from './App.jsx';
import ShopContextProvider from './context/ShopContext.jsx';
import { SSRDataProvider } from './context/SSRDataContext.jsx';
import { api } from './api/client.js';
import { headTags, pageMeta } from './seo.js';

const SORTS = { relevant: 'relevant', 'low-high': 'price_asc', 'high-low': 'price_desc' };
const listParam = (params, key) => (params.get(key) ? params.get(key).split(',') : []);

/** Server-rendered routes: "home" | "collection" | "product", or null (client-rendered). */
export function ssrRoute(pathname) {
  if (pathname === '/') return 'home';
  if (pathname === '/collection') return 'collection';
  if (/^\/product\/[^/]+$/.test(pathname)) return 'product';
  return null;
}

async function loadSSRData(pathname, search) {
  try {
    const route = ssrRoute(pathname);
    if (route === 'home') {
      const [latest, bestsellers] = await Promise.all([api.latest(10), api.bestsellers(5)]);
      return { route, latest, bestsellers };
    }
    if (route === 'collection') {
      const params = new URLSearchParams(search);
      const category = listParam(params, 'category');
      const subCategory = listParam(params, 'sub');
      const sortType = SORTS[params.get('sort')] ? params.get('sort') : 'relevant';
      // The search box's text lives in client-side ShopContext state, not the URL, so it is always empty
      // on a fresh page load (matching what the client would fetch on its own first render).
      const products = await api.products({ q: '', category, subCategory, sort: SORTS[sortType], page: 0, size: 20 });
      return { route, products };
    }
    if (route === 'product') {
      const product = await api.product(decodeURIComponent(pathname.split('/')[2]));
      return { route, product };
    }
  } catch (e) {
    // API unreachable, or (for a product) not found: fall back to no SSR data. App renders its normal
    // client-side loading / error state and fetches again in the browser.
    if (e?.status === 404) return { notFound: true };
    return null;
  }
  return null;
}

export async function render(url, { siteUrl = '' } = {}) {
  const [pathname, search = ''] = url.split('?');
  const loaded = await loadSSRData(pathname, search);
  const status = loaded?.notFound ? 404 : 200;
  const ssrData = loaded?.notFound ? null : loaded;
  const head = headTags(pageMeta({ pathname, search, ssrData, siteUrl }));

  // Session-dependent routes: send only the shell (the client renders them). Rendering them here would
  // only produce a "Loading..." placeholder or a redirect the server can't perform.
  if (!ssrData) return { html: '', ssrData: null, head, status };

  const html = ReactDOMServer.renderToString(
    <StaticRouter location={url}>
      <ShopContextProvider>
        <SSRDataProvider value={ssrData} siteUrl={siteUrl}>
          <App />
        </SSRDataProvider>
      </ShopContextProvider>
    </StaticRouter>,
  );

  return { html, ssrData, head, status };
}
