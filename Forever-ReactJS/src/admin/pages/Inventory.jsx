import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import useUnsavedChanges from "../../components/useUnsavedChanges";
import { Card, ClearFilters, Dropdown, Empty, ErrorText, Loading, MultiSelect, PageTitle, Pagination, SearchInput, Segmented, SortTh } from "../components/ui";
import { matches, paginate, sortRows, usePage, useSort, useUrlFilters, useUrlSearch } from "../table";
import { useOnProductSaved, useOpenProduct } from "../productDrawer";
import { z } from "@/lib/validation";

const PAGE_SIZE = 10;
const FILTER_DEFAULTS = { q: '', category: '', sub: '', level: 'all' };
const LOW_STOCK = 5;
const SIZE_ORDER = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
const sizeRank = (s) => (SIZE_ORDER.indexOf(s) === -1 ? 99 : SIZE_ORDER.indexOf(s));
const RESTOCK_STEPS = [5, 10, 20, 50];

const keyOf = (productId, size) => `${productId}:${size}`;
// Stock is a whole number from 0 up (the API's StockRequest), typed as text.
const stockSchema = z.string().trim().regex(/^\d+$/, 'Whole number, 0 or more').transform(Number).pipe(z.number().max(1_000_000, 'Too large'));
const isValidStock = (value) => stockSchema.safeParse(value).success;

const stockTone = (stock) => {
  if (stock === 0) return 'border-red-300 bg-red-50 text-red-700';
  if (stock <= LOW_STOCK) return 'border-amber-300 bg-amber-50 text-amber-800';
  return 'border-gray-200 bg-white';
};

const STATUS = {
  out: ['Out of stock', 'bg-red-50 text-red-700'],
  partly: ['Some sizes out', 'bg-red-50 text-red-700'],
  low: ['Low stock', 'bg-amber-50 text-amber-800'],
  ok: ['In stock', 'bg-green-50 text-green-700'],
};
const statusOf = (g) => {
  if (g.out === g.sizes.length) return 'out';
  if (g.out > 0) return 'partly';
  if (g.low > 0) return 'low';
  return 'ok';
};

// A summary card that doubles as a filter button.
const FilterStat = ({ label, value, hint, tone = '', active, onClick }) => (
  <button
    type="button"
    onClick={onClick}
    aria-pressed={active}
    className={`text-left bg-white border rounded-lg p-5 transition-colors ${
      active ? 'border-black ring-1 ring-black' : 'border-gray-200 hover:border-gray-400'
    }`}
  >
    <p className="text-sm text-gray-500">{label}</p>
    <p className={`text-3xl font-medium mt-2 ${tone}`}>{value}</p>
    {hint && <p className="text-xs text-gray-400 mt-1">{hint}</p>}
  </button>
);

// Stock for one size. Changes are drafts until "Save all"; a changed cell is blue and shows the saved value.
const StockCell = ({ row, draft, onChange }) => {
  const value = draft ?? String(row.stock);
  const changed = draft !== undefined && draft !== String(row.stock);
  const invalid = draft !== undefined && !isValidStock(draft);
  const tone = invalid
    ? 'border-red-500 bg-white ring-2 ring-red-200'
    : changed
      ? 'border-blue-500 bg-blue-50 text-blue-900 ring-2 ring-blue-200 font-medium'
      : stockTone(row.stock);

  return (
    <div className="flex flex-col items-center">
      <input
        type="text"
        inputMode="numeric"
        aria-invalid={invalid}
        value={value}
        onChange={(e) => onChange(row, e.target.value)}
        onFocus={(e) => e.target.select()}
        onKeyDown={(e) => e.key === 'Escape' && onChange(row, undefined)}
        aria-label={`Stock for ${row.productName} size ${row.size}`}
        title={changed ? `Saved value: ${row.stock} (Esc to undo)` : undefined}
        className={`w-14 rounded border px-1 py-1.5 text-center text-sm tabular-nums [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none ${tone}`}
      />
      <span className="h-3.5 text-[10px] leading-3.5 text-blue-600">{changed && !invalid ? `was ${row.stock}` : ''}</span>
    </div>
  );
};

const Inventory = () => {
  const [rows, setRows] = useState([]);
  const [products, setProducts] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  // Filters live in the URL; `category` and `sub` are comma-separated lists.
  const [filters, setFilters] = useUrlFilters(FILTER_DEFAULTS);
  const [searchText, setSearchText] = useUrlSearch(filters, setFilters);
  const search = filters.q;
  const categories = useMemo(() => (filters.category ? filters.category.split(',') : []), [filters.category]);
  const subs = useMemo(() => (filters.sub ? filters.sub.split(',') : []), [filters.sub]);
  const { level } = filters;
  const setLevel = (v) => setFilters({ level: v });
  const [sort, onSort] = useSort('total', 'asc');
  const [drafts, setDrafts] = useState({}); // "productId:size" -> typed value, until saved
  const [saving, setSaving] = useState(false);
  const openProduct = useOpenProduct();
  const [version, setVersion] = useState(0);
  useOnProductSaved(useCallback(() => setVersion((v) => v + 1), []));

  useEffect(() => {
    let cancelled = false;
    Promise.all([api.adminInventory(), api.adminProducts({ size: 100, sort: 'newest' }).catch(() => null)])
      .then(([inventory, productPage]) => {
        if (cancelled) return;
        setRows(inventory);
        const byId = {};
        (productPage?.content || []).forEach((p) => {
          byId[p.id] = p;
        });
        setProducts(byId);
      })
      .catch((e) => !cancelled && setError(e))
      .finally(() => !cancelled && setLoading(false));
    return () => {
      cancelled = true;
    };
  }, [version]);

  // One entry per product with its sizes, in size order.
  const groups = useMemo(() => {
    const map = new Map();
    rows.forEach((r) => {
      if (!map.has(r.productId)) {
        const p = products[r.productId];
        map.set(r.productId, {
          productId: r.productId,
          name: r.productName,
          image: p?.images?.[0],
          category: p ? `${p.category} · ${p.subCategory}` : '',
          categoryName: p?.category,
          subCategory: p?.subCategory,
          active: p ? p.active : true,
          sizes: [],
        });
      }
      map.get(r.productId).sizes.push(r);
    });
    return [...map.values()].map((g) => {
      const sizes = [...g.sizes].sort((a, b) => sizeRank(a.size) - sizeRank(b.size));
      const group = {
        ...g,
        sizes,
        total: sizes.reduce((sum, s) => sum + s.stock, 0),
        low: sizes.filter((s) => s.stock > 0 && s.stock <= LOW_STOCK).length,
        out: sizes.filter((s) => s.stock === 0).length,
      };
      return { ...group, status: statusOf(group) };
    });
  }, [rows, products]);

  // Size columns shared by every row, so the same size always lines up.
  const sizeColumns = useMemo(
    () => [...new Set(rows.map((r) => r.size))].sort((a, b) => sizeRank(a) - sizeRank(b)),
    [rows],
  );

  const categoryOptions = useMemo(
    () => [...new Set(Object.values(products).map((p) => p.category))].sort(),
    [products],
  );
  // Sub-categories of the chosen categories (all of them when no category is chosen).
  const subOptions = useMemo(
    () =>
      [...new Set(Object.values(products).filter((p) => !categories.length || categories.includes(p.category)).map((p) => p.subCategory))].sort(),
    [products, categories],
  );
  const setCategories = (list) => {
    // Drop chosen sub-categories that no longer exist in the chosen categories.
    const allowed = new Set(Object.values(products).filter((p) => !list.length || list.includes(p.category)).map((p) => p.subCategory));
    setFilters({ category: list.join(','), sub: subs.filter((s) => allowed.has(s)).join(',') });
  };
  const setSubs = (list) => setFilters({ sub: list.join(',') });

  const visible = useMemo(() => {
    const filtered = groups.filter((g) => {
      if (!matches(search, g.name, `#${g.productId}`, g.productId)) return false;
      if (categories.length && !categories.includes(g.categoryName)) return false;
      if (subs.length && !subs.includes(g.subCategory)) return false;
      if (level === 'low') return g.low > 0 || g.out > 0;
      if (level === 'out') return g.out > 0;
      return true;
    });
    return sortRows(filtered, sort, {
      name: (g) => g.name,
      total: (g) => g.total,
      status: (g) => ['out', 'partly', 'low', 'ok'].indexOf(g.status),
    });
  }, [groups, search, categories, subs, level, sort]);
  const [page, setPage] = usePage(JSON.stringify([search, categories, subs, level, sort]));

  // Height of the sticky filter bar (it wraps on narrow screens), so the table header can stick right below it.
  const barRef = useRef(null);
  const [barHeight, setBarHeight] = useState(0);
  useEffect(() => {
    const el = barRef.current;
    if (!el) return undefined;
    const observer = new ResizeObserver(() => setBarHeight(el.offsetHeight));
    observer.observe(el);
    return () => observer.disconnect();
  }, [loading]);
  // The pager is at the bottom, so a new page scrolls back to the top of the table.
  const tableTopRef = useRef(null);
  const goToPage = (p) => {
    setPage(p);
    tableTopRef.current?.scrollIntoView({ block: 'start', behavior: 'smooth' });
  };
  const paged = paginate(visible, page, PAGE_SIZE);

  const totals = useMemo(
    () => ({
      skus: rows.length,
      units: rows.reduce((sum, r) => sum + r.stock, 0),
      low: rows.filter((r) => r.stock > 0 && r.stock <= LOW_STOCK).length,
      out: rows.filter((r) => r.stock === 0).length,
    }),
    [rows],
  );

  // ---- drafts ----
  const rowByKey = useMemo(() => new Map(rows.map((r) => [keyOf(r.productId, r.size), r])), [rows]);
  const changes = Object.entries(drafts)
    .filter(([key, value]) => rowByKey.has(key) && value !== String(rowByKey.get(key).stock))
    .map(([key, value]) => ({ row: rowByKey.get(key), value }));
  const invalidCount = changes.filter((c) => !isValidStock(c.value)).length;
  const { dialog: leaveDialog } = useUnsavedChanges(changes.length > 0, 'You have stock changes that are not saved yet. Leave and discard them?');

  const setDraft = (row, value) =>
    setDrafts((all) => {
      const next = { ...all };
      if (value === undefined || value === String(row.stock)) delete next[keyOf(row.productId, row.size)];
      else next[keyOf(row.productId, row.size)] = value;
      return next;
    });

  const restock = (group, amount) =>
    setDrafts((all) => {
      const next = { ...all };
      group.sizes.forEach((row) => {
        const key = keyOf(row.productId, row.size);
        const current = isValidStock(next[key] ?? '') ? Number(next[key]) : row.stock;
        next[key] = String(current + amount);
      });
      return next;
    });

  const saveAll = async () => {
    if (invalidCount) return toast.error('Fix the highlighted cells: stock must be a whole number of 0 or more');
    setSaving(true);
    const results = await Promise.allSettled(changes.map(({ row, value }) => api.adminSetStock(row.productId, row.size, Number(value))));
    const saved = changes.filter((_, i) => results[i].status === 'fulfilled');
    const savedStock = new Map(saved.map(({ row, value }) => [keyOf(row.productId, row.size), Number(value)]));
    setRows((all) => all.map((r) => {
      const stock = savedStock.get(keyOf(r.productId, r.size));
      return stock === undefined ? r : { ...r, stock, lowStock: stock <= LOW_STOCK };
    }));
    setDrafts((all) => {
      const next = { ...all };
      savedStock.forEach((_, key) => delete next[key]);
      return next;
    });
    const failed = results.length - saved.length;
    if (failed) toast.error(`${failed} change${failed === 1 ? '' : 's'} could not be saved and ${failed === 1 ? 'is' : 'are'} still highlighted`);
    else toast.success(`Saved ${saved.length} stock change${saved.length === 1 ? '' : 's'}`);
    setSaving(false);
  };

  if (loading) return <Loading />;
  if (error) return <ErrorText error={error} />;

  const toggleLevel = (value) => setLevel(level === value ? 'all' : value);

  return (
    <>
      <PageTitle title="Inventory" />

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <FilterStat label="Products" value={groups.length} hint={`${totals.skus} sizes tracked`} active={level === 'all'} onClick={() => setLevel('all')} />
        <FilterStat label="Units in stock" value={totals.units.toLocaleString()} hint="across all sizes" active={false} onClick={() => setLevel('all')} />
        <FilterStat
          label="Low stock"
          value={totals.low}
          hint={`sizes with 1–${LOW_STOCK} left · click to filter`}
          tone={totals.low ? 'text-amber-600' : ''}
          active={level === 'low'}
          onClick={() => toggleLevel('low')}
        />
        <FilterStat
          label="Out of stock"
          value={totals.out}
          hint="sizes at 0 · click to filter"
          tone={totals.out ? 'text-red-600' : ''}
          active={level === 'out'}
          onClick={() => toggleLevel('out')}
        />
      </div>

      {/* Filters stay under the admin header while scrolling; the table header sticks just below them (wide screens). */}
      <div
        ref={barRef}
        className="sticky top-14 z-20 -mx-4 sm:-mx-6 mb-4 flex flex-wrap items-center gap-3 border-b border-gray-200 bg-gray-50/95 px-4 sm:px-6 py-3 backdrop-blur"
      >
        <SearchInput value={searchText} onChange={setSearchText} placeholder="Search product name or #id" />
        {categoryOptions.length > 0 && (
          <MultiSelect label="Categories" options={categoryOptions} value={categories} onChange={setCategories} />
        )}
        {subOptions.length > 0 && <MultiSelect label="Sub-categories" options={subOptions} value={subs} onChange={setSubs} />}
        {(searchText || categories.length > 0 || subs.length > 0 || level !== 'all') && (
          <ClearFilters
            count={[searchText, categories.length, subs.length, level !== 'all'].filter(Boolean).length}
            onClick={() => {
              setSearchText('');
              setFilters({ q: '', category: '', sub: '', level: 'all' });
            }}
          />
        )}
        <Segmented
          value={level}
          onChange={setLevel}
          options={[
            ['all', 'All'],
            ['low', 'Low & out'],
            ['out', 'Out of stock'],
          ]}
        />
        <span className="text-sm text-gray-500">{visible.length} products</span>
      </div>

      <p className="mb-2 text-xs text-gray-400">
        Type new amounts or use Restock, then review and press <b className="font-medium text-gray-500">Save all</b>. Esc undoes a cell.
      </p>

      <div ref={tableTopRef} className="scroll-mt-40" aria-hidden="true" />
      {/* overflow-x scrolls the table on small screens; on wide ones it is visible so the header can stick. */}
      <Card className="overflow-x-auto lg:overflow-visible">
        {visible.length === 0 ? (
          <Empty>No products match these filters</Empty>
        ) : (
          <table className="w-full text-sm" style={{ '--inv-bar': `${barHeight}px` }}>
            <thead className="bg-gray-50 text-gray-500 text-left lg:sticky lg:top-[calc(3.5rem+var(--inv-bar))] lg:z-10 lg:shadow-[0_1px_0_#e5e7eb]">
              <tr>
                <SortTh label="Product" sortKey="name" sort={sort} onSort={onSort} />
                <SortTh label="Status" sortKey="status" sort={sort} onSort={onSort} className="hidden md:table-cell" />
                {sizeColumns.map((size) => (
                  <th key={size} className="px-1 py-3 font-normal text-center w-16">{size}</th>
                ))}
                <SortTh label="Total" sortKey="total" sort={sort} onSort={onSort} className="text-right" />
                <th className="px-4 py-3 font-normal text-right">Restock</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {paged.rows.map((g) => {
                const bySize = new Map(g.sizes.map((s) => [s.size, s]));
                const [statusLabel, statusClass] = STATUS[g.status];
                return (
                  <tr key={g.productId} className="hover:bg-gray-50/60">
                    <td className="px-4 py-2">
                      <div className="flex items-center gap-3 min-w-[13rem]">
                        {g.image && <img src={g.image} alt="" className={`w-9 h-11 object-cover rounded ${g.active ? '' : 'opacity-50'}`} />}
                        <div className="min-w-0">
                          <button type="button" onClick={() => openProduct(g.productId)} className="text-left font-medium hover:underline line-clamp-1">
                            {g.name}
                          </button>
                          <p className="text-xs text-gray-400">
                            #{g.productId}
                            {g.category && ` · ${g.category}`}
                            {!g.active && ' · Hidden'}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-2 hidden md:table-cell">
                      <span className={`whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-medium ${statusClass}`}>{statusLabel}</span>
                    </td>
                    {sizeColumns.map((size) => (
                      <td key={size} className="px-1 pt-2 text-center">
                        {bySize.has(size) ? (
                          <StockCell row={bySize.get(size)} draft={drafts[keyOf(g.productId, size)]} onChange={setDraft} />
                        ) : (
                          <span className="text-gray-300" title={`Not sold in ${size}`}>—</span>
                        )}
                      </td>
                    ))}
                    <td className="px-4 py-2 text-right font-medium tabular-nums">{g.total}</td>
                    <td className="px-4 py-2 text-right">
                      {/* Action menu: always shows "+ Add" ("" option), each pick adds stock as a draft. */}
                      <Dropdown
                        value=""
                        onChange={(v) => v && restock(g, Number(v))}
                        aria-label={`Restock ${g.name}`}
                        options={[['', '+ Add'], ...RESTOCK_STEPS.map((n) => [String(n), `+${n} each size`])]}
                        className="ml-auto h-7 w-auto min-w-[5.5rem] px-2 text-xs text-gray-600"
                      />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>
      <Pagination page={paged.page} totalPages={paged.totalPages} total={paged.total} pageSize={paged.pageSize} onChange={goToPage} />

      {changes.length > 0 && (
        <div className="sticky bottom-4 z-20 mt-4 flex flex-wrap items-center gap-3 rounded-lg border border-blue-200 bg-white px-4 py-3 shadow-lg">
          {/* Buttons on the left: toasts appear bottom-right and must not cover them. */}
          <div className="flex gap-2">
            <button type="button" onClick={saveAll} disabled={saving || invalidCount > 0} className="rounded bg-black px-4 py-2 text-sm text-white disabled:bg-gray-400">
              {saving ? 'Saving…' : `Save all (${changes.length})`}
            </button>
            <button type="button" onClick={() => setDrafts({})} disabled={saving} className="rounded border border-gray-300 px-4 py-2 text-sm hover:bg-gray-50 disabled:opacity-50">
              Discard
            </button>
          </div>
          <p className="text-sm">
            <b className="font-medium">{changes.length}</b> unsaved stock change{changes.length === 1 ? '' : 's'}
            {invalidCount > 0 && <span className="text-red-600"> · {invalidCount} invalid</span>}
          </p>
        </div>
      )}
      {leaveDialog}
    </>
  );
};

export default Inventory;
