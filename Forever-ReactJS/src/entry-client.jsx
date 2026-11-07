// Client entry: hydrates the markup the SSR server sent (Home / Collection / Product) using the data it
// embedded in `window.__SSR_DATA__`, or does a plain client render (createRoot) when there is none
// (session-dependent pages such as cart / checkout / admin, or the bundle served without the SSR server).
import { createRoot, hydrateRoot } from 'react-dom/client'
import App from './App.jsx'
import './index.css'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import ShopContextProvider from './context/ShopContext.jsx'
import { SSRDataProvider } from './context/SSRDataContext.jsx'

const ssrData = window.__SSR_DATA__ ?? null;
// Same absolute origin the server used for share links / og:url, so hydration sees identical markup.
const siteUrl = window.__SITE_URL__ || window.location.origin;

// Same data router as before (useBlocker, used by the admin forms / Profile, needs one) — just rendered
// via hydrateRoot when the server already sent HTML for this URL.
const router = createBrowserRouter([
  {
    path: '*',
    element: (
      <ShopContextProvider>
        <SSRDataProvider value={ssrData} siteUrl={siteUrl}>
          <App/>
        </SSRDataProvider>
      </ShopContextProvider>
    ),
  },
]);

const rootEl = document.getElementById('root');
if (ssrData) {
  hydrateRoot(rootEl, <RouterProvider router={router} />);
} else {
  createRoot(rootEl).render(<RouterProvider router={router} />);
}
