// Small Express server implementing Vite's documented SSR pattern: in dev it uses Vite's middleware +
// `ssrLoadModule` so there's HMR; in production it serves the pre-built client bundle and imports the
// pre-built server bundle. Same server for both; only the `isProd` branches differ.
//
// Runtime environment variables (all optional — see README.md):
//   PORT             port to listen on (default 5173)
//   PUBLIC_SITE_URL  absolute public origin, e.g. https://shop.example.com — used for og:url, canonical and
//                    share links. When unset it is derived from the request (X-Forwarded-Proto / -Host
//                    first, so it is right behind a reverse proxy).
//   SSR_API_URL      API base URL for the server-side data fetches only (e.g. http://api:8989 inside
//                    Docker). Falls back to the build-time VITE_API_URL, which browsers use.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const isProd = process.env.NODE_ENV === 'production';
const port = Number(process.env.PORT) || 5173;
const root = __dirname;
const PUBLIC_SITE_URL = (process.env.PUBLIC_SITE_URL || '').trim().replace(/\/+$/, '');

// First value of a possibly comma-separated forwarded header.
const firstHeader = (req, name) => (req.get(name) || '').split(',')[0].trim();

/** Absolute origin for this request: PUBLIC_SITE_URL, else the (proxied) request's own scheme + host. */
function siteUrlFor(req) {
  if (PUBLIC_SITE_URL) return PUBLIC_SITE_URL;
  const proto = firstHeader(req, 'x-forwarded-proto') || req.protocol || 'http';
  const host = firstHeader(req, 'x-forwarded-host') || req.get('host') || `localhost:${port}`;
  // Only plain host[:port] values are trusted into the page (the header is client-controlled).
  const safeHost = /^[A-Za-z0-9.\-[\]:]+$/.test(host) ? host : `localhost:${port}`;
  const safeProto = proto === 'https' ? 'https' : 'http';
  return `${safeProto}://${safeHost}`;
}

const jsonForScript = (value) => JSON.stringify(value).replace(/</g, '\\u003c');

async function createServer() {
  const app = express();
  let vite;

  if (!isProd) {
    const { createServer: createViteServer } = await import('vite');
    vite = await createViteServer({
      root,
      server: { middlewareMode: true },
      appType: 'custom',
    });
    app.use(vite.middlewares);
  } else {
    const compression = (await import('compression')).default;
    const sirv = (await import('sirv')).default;
    app.use(compression());
    app.use(sirv(path.resolve(root, 'dist/client'), { extensions: [] }));
  }

  app.use(async (req, res) => {
    const url = req.originalUrl;
    try {
      let template;
      let render;
      if (!isProd) {
        template = await fs.readFile(path.resolve(root, 'index.html'), 'utf-8');
        template = await vite.transformIndexHtml(url, template);
        render = (await vite.ssrLoadModule('/src/entry-server.jsx')).render;
      } else {
        template = await fs.readFile(path.resolve(root, 'dist/client/index.html'), 'utf-8');
        render = (await import('./dist/server/entry-server.js')).render;
      }

      const siteUrl = siteUrlFor(req);
      const { html: appHtml, ssrData, head, status } = await render(url, { siteUrl });
      // `</` inside the JSON would prematurely close the <script> tag; escaping it keeps the payload inert.
      const dataScript = `<script>window.__SSR_DATA__ = ${ssrData ? jsonForScript(ssrData) : 'null'};` +
        `window.__SITE_URL__ = ${jsonForScript(siteUrl)};</script>`;

      const html = template
        .replace('<!--ssr-head-->', head)
        .replace('<!--ssr-outlet-->', appHtml)
        .replace('<!--ssr-data-->', dataScript);
      res.status(status || 200).set({ 'Content-Type': 'text/html' }).end(html);
    } catch (e) {
      vite?.ssrFixStacktrace(e);
      console.error(e);
      res.status(500).end(isProd ? 'Internal Server Error' : e.stack);
    }
  });

  return app;
}

createServer().then((app) =>
  app.listen(port, () => {
    console.log(`Forever storefront (SSR) listening on http://localhost:${port}`);
  }),
);
