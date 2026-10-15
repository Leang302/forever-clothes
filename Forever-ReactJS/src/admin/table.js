// Small helpers for searchable / sortable admin tables.
import { useEffect, useRef, useState } from "react";
import { useSearchParams } from "react-router-dom";

// Returns `value` after it stopped changing for `delay` ms (for search boxes).
export function useDebounced(value, delay = 300) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

// Sort state for <SortTh>: clicking the active column flips direction, a new column starts with `firstDir(key)`.
export function useSort(initialKey, initialDir = 'asc', firstDir = () => 'asc') {
  const [sort, setSort] = useState({ key: initialKey, dir: initialDir });
  const onSort = (key) =>
    setSort((s) => (s.key === key ? { key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key, dir: firstDir(key) }));
  return [sort, onSort, setSort];
}

// Client-side sort of `rows` by `getters[sort.key](row)` (strings compare case-insensitively).
export function sortRows(rows, sort, getters) {
  const get = getters[sort.key];
  if (!get) return rows;
  const factor = sort.dir === 'asc' ? 1 : -1;
  return [...rows].sort((a, b) => {
    const x = get(a);
    const y = get(b);
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    if (typeof x === 'string' || typeof y === 'string') return String(x).localeCompare(String(y), undefined, { sensitivity: 'base' }) * factor;
    return (x - y) * factor;
  });
}

export const matches = (query, ...fields) => {
  const q = query.trim().toLowerCase();
  return !q || fields.some((f) => f != null && String(f).toLowerCase().includes(q));
};

// Page number that falls back to 0 whenever `filterKey` (e.g. JSON of the filters) changes, without an extra render/fetch.
export function usePage(filterKey) {
  const [state, setState] = useState({ key: filterKey, page: 0 });
  const page = state.key === filterKey ? state.page : 0;
  return [page, (p) => setState({ key: filterKey, page: p })];
}

/**
 * Filter values kept in the URL query, so they survive a refresh, can be shared and work with back/forward.
 * `defaults` maps each param to its default ("" = not set); defaults are left out of the URL.
 * Returns [values, set] where `set({ key: value, ... })` updates several params in one history entry.
 */
export function useUrlFilters(defaults) {
  const [params, setParams] = useSearchParams();
  const values = Object.fromEntries(Object.entries(defaults).map(([k, d]) => [k, params.get(k) ?? d]));
  const set = (changes) =>
    setParams(
      (prev) => {
        const next = new URLSearchParams(prev);
        Object.entries(changes).forEach(([k, v]) => {
          if (v == null || v === '' || v === defaults[k]) next.delete(k);
          else next.set(k, String(v));
        });
        return next;
      },
      { replace: true },
    );
  return [values, set];
}

/**
 * Search box text for a URL filter: typing updates the box at once and the URL `key` after `delay` ms.
 * Changes to the URL from elsewhere (Clear filters, back button) are copied back into the box.
 */
export function useUrlSearch(values, set, key = 'q', delay = 300) {
  const urlValue = values[key];
  const [text, setText] = useState(urlValue);
  const written = useRef(urlValue);
  const debounced = useDebounced(text, delay);

  useEffect(() => {
    if (debounced === written.current) return;
    written.current = debounced;
    set({ [key]: debounced.trim() });
    // eslint-disable-next-line react-hooks/exhaustive-deps -- `set` is recreated every render
  }, [debounced, key]);

  useEffect(() => {
    if (urlValue === written.current.trim()) return;
    written.current = urlValue;
    setText(urlValue);
  }, [urlValue]);

  return [text, setText];
}

// One page of an in-memory list plus the page count for <Pagination>. The page is clamped, so deleting the
// last row of the last page shows the previous page instead of an empty one.
export function paginate(rows, page, size) {
  const totalPages = Math.max(1, Math.ceil(rows.length / size));
  const current = Math.min(page, totalPages - 1);
  return { rows: rows.slice(current * size, (current + 1) * size), page: current, totalPages, total: rows.length, pageSize: size };
}
