// Stock helpers shared by the product page, the product cards' quick-add panel and the cart.
// The API sends `stock` as { "<size>": unitsLeft } (same order as `sizes`) and `inStock` (active AND at
// least one size > 0). `active` alone is NOT a stock signal.

export const MAX_QTY = 99; // matches AddItemRequest's @Max(99) on the API
export const LOW_STOCK = 5; // "Only N left" at or below this

/** Units left in `size` (0 when the size is unknown). */
export const sizeStock = (product, size) => Math.max(0, Number(product?.stock?.[size] ?? 0));

/** Sizes that can actually be bought right now. */
export const buyableSizes = (product) => (product?.sizes || []).filter((s) => sizeStock(product, s) > 0);

/** Highest quantity the shopper may pick for `size`. */
export const maxQty = (product, size) => Math.min(MAX_QTY, sizeStock(product, size));

/** { text, tone } describing availability for one size, or the product overall when `size` is empty. */
export const availability = (product, size) => {
  if (!size) {
    return product?.inStock ? { text: 'In stock', tone: 'ok' } : { text: 'Out of stock', tone: 'out' };
  }
  const left = sizeStock(product, size);
  if (left === 0) return { text: 'Out of stock', tone: 'out' };
  if (left <= LOW_STOCK) return { text: `Only ${left} left`, tone: 'low' };
  return { text: 'In stock', tone: 'ok' };
};

export const toneClass = { ok: 'text-green-700', low: 'text-amber-600', out: 'text-red-500' };

/**
 * Why a cart line can't be bought as is (its size sold out, or stock dropped below the quantity in the
 * cart — the API sends `stock` = units left for the line's size), or null when it's fine.
 */
export const lineProblem = (item) => {
  if (item.stock == null) return null;
  if (item.stock <= 0) return `Out of stock in size ${item.size}. Remove it to check out.`;
  if (item.quantity > item.stock) return `Only ${item.stock} left in size ${item.size}. Reduce the quantity to ${item.stock} to check out.`;
  return null;
};

/** Clamps a typed quantity to 1..max (max ≥ 1). */
export const clampQty = (value, max) => {
  const n = Math.trunc(Number(value));
  if (!Number.isFinite(n)) return 1;
  return Math.min(Math.max(1, max), Math.max(1, n));
};
