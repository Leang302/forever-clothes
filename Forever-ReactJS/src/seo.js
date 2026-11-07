// Per-page <head> tags for the server-rendered HTML (title, description, Open Graph, Twitter card), so
// link previews on Facebook / Telegram / X show the right product. Crawlers don't run JavaScript, so these
// must be in the HTML the server sends; the client only updates document.title while navigating.

const SITE_NAME = 'Forever';
const DEFAULT_DESCRIPTION =
  'Forever — shop the latest men, women and kids fashion. Cash on delivery or pay by KHQR.';

const escapeHtml = (value) =>
  String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const clip = (text, max = 200) => {
  const clean = String(text ?? '').replace(/\s+/g, ' ').trim();
  return clean.length > max ? `${clean.slice(0, max - 1).trimEnd()}…` : clean;
};

const absolute = (url, siteUrl) => {
  if (!url) return '';
  try {
    return new URL(url, siteUrl + '/').href;
  } catch {
    return '';
  }
};

/** Meta values for a route, from the same data the page was rendered with. */
export function pageMeta({ pathname, search = '', ssrData, siteUrl }) {
  const url = siteUrl + pathname + (search ? `?${search}` : '');
  if (ssrData?.route === 'product' && ssrData.product) {
    const p = ssrData.product;
    const price = Number(p.price).toFixed(2);
    return {
      title: `${p.name} — $${price} | ${SITE_NAME}`,
      description: clip(`${p.description} · $${price}${p.inStock ? '' : ' · Out of stock'}`),
      image: absolute(p.images?.[0], siteUrl),
      url,
      type: 'product',
      price,
    };
  }
  if (pathname === '/collection') {
    return {
      title: `All collections | ${SITE_NAME}`,
      description: 'Browse every Forever product — filter by category and sort by price.',
      image: absolute(ssrData?.products?.content?.[0]?.images?.[0], siteUrl),
      url,
      type: 'website',
    };
  }
  return {
    title: pathname === '/' ? `${SITE_NAME} — Latest fashion` : SITE_NAME,
    description: DEFAULT_DESCRIPTION,
    image: absolute(ssrData?.latest?.[0]?.images?.[0], siteUrl),
    url,
    type: 'website',
  };
}

/** The tags as an HTML string for the template's <!--ssr-head--> slot. */
export function headTags(meta) {
  const tags = [
    `<title>${escapeHtml(meta.title)}</title>`,
    `<meta name="description" content="${escapeHtml(meta.description)}" />`,
    `<link rel="canonical" href="${escapeHtml(meta.url)}" />`,
    `<meta property="og:site_name" content="${SITE_NAME}" />`,
    `<meta property="og:type" content="${escapeHtml(meta.type)}" />`,
    `<meta property="og:title" content="${escapeHtml(meta.title)}" />`,
    `<meta property="og:description" content="${escapeHtml(meta.description)}" />`,
    `<meta property="og:url" content="${escapeHtml(meta.url)}" />`,
    meta.image && `<meta property="og:image" content="${escapeHtml(meta.image)}" />`,
    meta.price && `<meta property="product:price:amount" content="${escapeHtml(meta.price)}" />`,
    meta.price && `<meta property="product:price:currency" content="USD" />`,
    `<meta name="twitter:card" content="${meta.image ? 'summary_large_image' : 'summary'}" />`,
    `<meta name="twitter:title" content="${escapeHtml(meta.title)}" />`,
    `<meta name="twitter:description" content="${escapeHtml(meta.description)}" />`,
    meta.image && `<meta name="twitter:image" content="${escapeHtml(meta.image)}" />`,
  ];
  return tags.filter(Boolean).join('\n    ');
}
