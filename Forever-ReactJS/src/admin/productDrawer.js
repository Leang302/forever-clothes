// The add/edit product form opens as a drawer over any admin page via the `?product=new` / `?product=<id>`
// URL param, so the page underneath (and its filters) stays put. ProductDrawerHost renders it.
import { useEffect } from "react";
import { useSearchParams } from "react-router-dom";

export const PRODUCT_PARAM = 'product';
// Pre-filled category / sub-category for a new product (e.g. "+ Add product" on the Categories page).
export const PRODUCT_CATEGORY_PARAM = 'productCategory';
export const PRODUCT_SUB_PARAM = 'productSub';
const SAVED_EVENT = 'admin:product-saved';

/**
 * Returns `open(idOrNew, prefill?)`, which opens the product drawer on the current page.
 * `prefill` ({ category, subCategory }) applies to a new product.
 */
export function useOpenProduct() {
  const [, setParams] = useSearchParams();
  return (idOrNew, prefill = {}) =>
    setParams((prev) => {
      const next = new URLSearchParams(prev);
      next.set(PRODUCT_PARAM, String(idOrNew));
      next.delete(PRODUCT_CATEGORY_PARAM);
      next.delete(PRODUCT_SUB_PARAM);
      if (idOrNew === 'new' && prefill.category) next.set(PRODUCT_CATEGORY_PARAM, prefill.category);
      if (idOrNew === 'new' && prefill.subCategory) next.set(PRODUCT_SUB_PARAM, prefill.subCategory);
      return next;
    });
}

/** Runs `callback` after any product is created or saved in the drawer, e.g. to reload a list. */
export function useOnProductSaved(callback) {
  useEffect(() => {
    window.addEventListener(SAVED_EVENT, callback);
    return () => window.removeEventListener(SAVED_EVENT, callback);
  }, [callback]);
}

export const announceProductSaved = () => window.dispatchEvent(new Event(SAVED_EVENT));
