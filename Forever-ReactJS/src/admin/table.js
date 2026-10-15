// Small helpers for searchable / sortable admin tables.
import { useEffect, useState } from "react";

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
