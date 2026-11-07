# Forever — React storefront (SSR)

React 18 + Vite storefront and admin panel for the Forever shop, server-side rendered by a small Express
server (`server.js`, Vite's documented SSR pattern). It talks to the Spring Boot API in `../Forever-API`.

## Running

```bash
cp .env.example .env.local     # VITE_API_URL=http://localhost:8989 (default)
npm install
npm run dev                    # SSR dev server with HMR on http://localhost:5173 (node server.js)
npm run build                  # client bundle -> dist/client, server bundle -> dist/server
npm start                      # production SSR server (NODE_ENV=production node server.js)
npm run lint
```

`npm run dev:csr` still runs plain Vite (client-side rendering only, no SSR, no meta tags) if you need it.

Shoppers don't need an account. A guest is an anonymous **cart session**, never a login: the first
**Add to cart** starts one (`POST /api/guest-sessions`), its opaque token is kept in `localStorage`
(`forever.guestSession`, separate from the login tokens in `forever.tokens`) and sent as `X-Guest-Session` on
`/api/cart/**`, `/api/checkout/**`, `POST /api/orders` and `POST /api/khqr/checkout` only — never together with
`Authorization`. Browsing, and even opening `/cart`, never creates one (the API allows 20 per client IP per hour;
its `429 TOO_MANY_GUEST_SESSIONS` message is shown if hit). An expired session (`401 GUEST_SESSION_EXPIRED`) is
dropped; a new one starts on the next add. A placed guest order returns a `guestAccessToken`, kept in
`sessionStorage` (`forever.orderAccess.<id>`, this tab only) for the confirmation / KHQR polling via
`/api/guest-orders/{id}` + `X-Order-Access`. Logging in or registering ends the guest session
(`DELETE /api/guest-sessions/current`): the guest cart is not merged and guest orders are not attached.
Customers sign up / log in with an e-mail OTP (Mailpit at http://localhost:8025 in dev).

## Environment variables

| Variable | When | Used by | Purpose |
|---|---|---|---|
| `VITE_API_URL` | **build time** (baked into the JS bundle) | browser (and SSR fallback) | Public API base URL the browser calls, e.g. `https://api.example.com`. Default `http://localhost:8989`. |
| `SSR_API_URL` | runtime | SSR server only | API base URL for the server-side data fetches, e.g. `http://api:8989` on a Docker network. Falls back to `VITE_API_URL`. Never sent to browsers. |
| `PUBLIC_SITE_URL` | runtime | SSR server | Absolute public origin of the storefront, e.g. `https://shop.example.com` (trailing `/` ignored). Used for `og:url`, `<link rel="canonical">` and the Facebook/Telegram share links. When unset it is derived from the request: `X-Forwarded-Proto` / `X-Forwarded-Host` (first value) if a reverse proxy sets them, else the request's own scheme + `Host`. Set it in production so a spoofed `Host` header can't change it. |
| `PORT` | runtime | SSR server | Listen port (default `5173`). |
| `NODE_ENV` | runtime | SSR server | `production` serves `dist/` (what `npm start` sets); anything else runs the Vite dev middleware. |

Example (Docker-style): build with `VITE_API_URL=https://api.example.com npm run build`, then run
`PUBLIC_SITE_URL=https://shop.example.com SSR_API_URL=http://api:8989 PORT=8080 npm start`.

## What is server-rendered, and why

| Route | SSR? | Server fetches |
|---|---|---|
| `/` | yes | latest (10) + bestsellers (5) |
| `/collection` (incl. `?category=…&sub=…&sort=…`) | yes | first page of products for those filters |
| `/product/:id` | yes (404 status for an unknown id) | the product |
| everything else (`/cart`, `/place-order`, `/order-confirmation/:id`, `/order*`, `/profile`, `/wishlist`, `/login`, `/admin/**`, …) | no — HTML shell, rendered in the browser | — |

* The public pages are rendered with real data (names, prices, descriptions, per-size stock) plus per-page
  `<title>`, `<meta name="description">`, Open Graph (`og:title`, `og:description`, `og:image` (absolute),
  `og:url`, `og:type=product` on product pages) and `twitter:card` tags, so search engines and Facebook /
  Telegram link previews (which don't run JavaScript) see the content. The data is embedded as
  `window.__SSR_DATA__` and the browser hydrates from it — the SSR'd data is not fetched again, and it is used
  only for that first render (navigating back to `/` later fetches fresh data).
* Session pages are **not** server-rendered on purpose: the shopper's session (access + refresh token) lives
  in the browser's `localStorage`, which is never sent to the server — there is no cookie. The SSR server
  therefore can't know who is asking, can't load their cart / orders / admin data (the API rejects anonymous
  calls), and would only produce a "Loading…" placeholder or a wrong redirect. For those URLs the server
  sends the shell (`<div id="root"></div>`, `window.__SSR_DATA__ = null`) and the client renders them with
  `createRoot`, exactly like a CSR app. Moving the session to an HttpOnly cookie would be the prerequisite for
  SSR'ing them.
* Things that depend on the session on SSR'd pages (the cart count, wishlist hearts, hiding shop buttons for
  admins) render the anonymous state on the server and on the first client render, then update after
  hydration, so there is no hydration mismatch (verified in a real browser, see E2E below).

## E2E tests (Playwright)

The specs in `e2e/` drive a real Chromium against the **real stack** — API on :8989 started against the
dev-only fake Bakong on :9099 (`../Forever-API/dev/fake-bakong.mjs`), Postgres/MinIO/Mailpit in Docker
(`docker compose up -d` in `../Forever-API`). Nothing is faked in the storefront: a KHQR payment is simulated
at the fake Bakong (`POST :9099/__pay_qr`) and the app's normal verify polling picks it up.

```bash
npm run dev &                  # the suite expects the SSR dev server on :5173
npm run test:e2e               # against the dev server
npm run test:e2e:prod          # builds, starts `npm start` on :4173 for the run, runs the same suite
npx playwright show-report     # HTML report
```

`E2E_BASE_URL`, `E2E_API_URL`, `E2E_BAKONG_URL` override the URLs. The specs create their own fixture
products through the admin API (and hide / remove them afterwards), check orders in Postgres with
`docker exec forever-postgres psql …`, and run serially. Products that ended up in test orders are only
hidden (the API's delete is a soft delete), so past orders keep showing them.

## Admin panel

Signed-in users with the `ADMIN` role get an **Admin panel** button in the profile menu (top right; in the menu on phones),
which opens `/admin`: dashboard, products (search, show/hide, create and edit — image upload and/or image URLs, stock and
visibility saved in one request; deleting hides the product from the shop), inventory (per-size stock), categories,
coupons, customers and orders (filter by status, move through the fulfilment steps, see items with quantity, unit price and
subtotal, and the delivery address).

* Everyone else - guests and customers - is silently sent back to the home page when they open an `/admin` URL, and the button
  is not rendered for them. The API enforces the role on every `/api/admin/**` call as well (a 403 also sends the user home).
* Dev admin account: `admin@forever.com` / `Admin@12345` (seeded by the API; change it for anything beyond local development).
