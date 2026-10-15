import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import { Card, Empty, ErrorText, Loading, MultiSelect, PageTitle, SearchInput, Segmented, SortTh, Stat } from "../components/ui";
import { matches, sortRows, useSort } from "../table";

const LOW_STOCK = 5;
const SIZE_ORDER = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
const sizeRank = (s) => (SIZE_ORDER.indexOf(s) === -1 ? 99 : SIZE_ORDER.indexOf(s));

const stockTone = (stock) => {
  if (stock === 0) return 'border-red-300 bg-red-50 text-red-700';
  if (stock <= LOW_STOCK) return 'border-amber-300 bg-amber-50 text-amber-800';
  return 'border-gray-300 bg-white';
};

// One size of one product: editable stock that saves on Enter or when the field loses focus.
const StockCell = ({ row, onSaved }) => {
  const [value, setValue] = useState(String(row.stock));
  const [state, setState] = useState('idle'); // idle | saving | saved

  useEffect(() => setValue(String(row.stock)), [row.stock]);

  const save = async () => {
    const next = Number(value);
    if (value === '' || !Number.isInteger(next) || next < 0) {
      toast.error('Stock must be a whole number of 0 or more');
      setValue(String(row.stock));
      return;
    }
    if (next === row.stock) return;
    setState('saving');
    try {
      await api.adminSetStock(row.productId, row.size, next);
      onSaved(row, next);
      setState('saved');
      setTimeout(() => setState('idle'), 1500);
    } catch (e) {
      toast.error(e.message);
      setValue(String(row.stock));
      setState('idle');
    }
  };

  return (
    <label className="flex flex-col items-center gap-1">
      <span className="text-xs text-gray-500">{row.size}</span>
      <input
        type="number"
        min="0"
        inputMode="numeric"
        value={value}
        disabled={state === 'saving'}
        onChange={(e) => setValue(e.target.value)}
        onBlur={save}
        onKeyDown={(e) => {
          if (e.key === 'Enter') e.currentTarget.blur();
          if (e.key === 'Escape') setValue(String(row.stock));
        }}
        aria-label={`Stock for ${row.productName} size ${row.size}`}
        className={`w-16 rounded border px-2 py-1 text-center text-sm ${stockTone(row.stock)} disabled:opacity-50`}
      />
      <span className={`h-4 text-[11px] ${state === 'saved' ? 'text-green-600' : 'text-gray-400'}`}>
        {state === 'saving' ? 'Saving…' : state === 'saved' ? '✓ Saved' : ''}
      </span>
    </label>
  );
};

const Inventory = () => {
  const [rows, setRows] = useState([]);
  const [products, setProducts] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [search, setSearch] = useState('');
  const [categories, setCategories] = useState([]);
  const [level, setLevel] = useState('all');
  const [sort, onSort] = useSort('total', 'asc');

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
  }, []);

  const onSaved = (row, stock) =>
    setRows((all) =>
      all.map((r) => (r.productId === row.productId && r.size === row.size ? { ...r, stock, lowStock: stock <= LOW_STOCK } : r)),
    );

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
          active: p ? p.active : true,
          sizes: [],
        });
      }
      map.get(r.productId).sizes.push(r);
    });
    return [...map.values()].map((g) => {
      const sizes = [...g.sizes].sort((a, b) => sizeRank(a.size) - sizeRank(b.size));
      return {
        ...g,
        sizes,
        total: sizes.reduce((sum, s) => sum + s.stock, 0),
        low: sizes.filter((s) => s.stock > 0 && s.stock <= LOW_STOCK).length,
        out: sizes.filter((s) => s.stock === 0).length,
      };
    });
  }, [rows, products]);

  const categoryOptions = useMemo(
    () => [...new Set(Object.values(products).map((p) => p.category))].sort(),
    [products],
  );

  const visible = useMemo(() => {
    const filtered = groups.filter((g) => {
      if (!matches(search, g.name, `#${g.productId}`, g.productId)) return false;
      if (categories.length && !categories.includes(g.categoryName)) return false;
      if (level === 'low') return g.low > 0 || g.out > 0;
      if (level === 'out') return g.out > 0;
      return true;
    });
    return sortRows(filtered, sort, {
      name: (g) => g.name,
      total: (g) => g.total,
    });
  }, [groups, search, categories, level, sort]);

  const totals = useMemo(
    () => ({
      skus: rows.length,
      units: rows.reduce((sum, r) => sum + r.stock, 0),
      low: rows.filter((r) => r.stock > 0 && r.stock <= LOW_STOCK).length,
      out: rows.filter((r) => r.stock === 0).length,
    }),
    [rows],
  );

  if (loading) return <Loading />;
  if (error) return <ErrorText error={error} />;

  return (
    <>
      <PageTitle title="Inventory" />

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <Stat label="SKUs" value={totals.skus} hint={`${groups.length} products`} />
        <Stat label="Units in stock" value={totals.units} />
        <Stat label="Low stock" value={totals.low} hint={`1–${LOW_STOCK} left`} tone={totals.low ? 'text-amber-600' : ''} />
        <Stat label="Out of stock" value={totals.out} hint="sizes at 0" tone={totals.out ? 'text-red-600' : ''} />
      </div>

      <div className="flex flex-wrap items-center gap-3 mb-4">
        <SearchInput value={search} onChange={setSearch} placeholder="Search product name or #id" />
        {categoryOptions.length > 0 && (
          <MultiSelect label="Categories" options={categoryOptions} value={categories} onChange={setCategories} />
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

      <Card className="overflow-x-auto">
        {visible.length === 0 ? (
          <Empty>No products match these filters</Empty>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-left">
              <tr>
                <SortTh label="Product" sortKey="name" sort={sort} onSort={onSort} />
                <th className="px-4 py-3 font-normal">
                  Stock per size <span className="text-xs text-gray-400">(Enter to save)</span>
                </th>
                <SortTh label="Total" sortKey="total" sort={sort} onSort={onSort} className="text-right" />
              </tr>
            </thead>
            <tbody className="divide-y">
              {visible.map((g) => (
                <tr key={g.productId} className="align-top">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3 min-w-[12rem]">
                      {g.image && <img src={g.image} alt="" className={`w-10 h-12 object-cover rounded ${g.active ? '' : 'opacity-50'}`} />}
                      <div className="min-w-0">
                        <Link to={`/admin/products/${g.productId}/edit`} className="font-medium hover:underline">
                          {g.name}
                        </Link>
                        <p className="text-xs text-gray-400">
                          #{g.productId}
                          {g.category && ` · ${g.category}`}
                          {!g.active && ' · Hidden'}
                        </p>
                        {(g.out > 0 || g.low > 0) && (
                          <p className="mt-1 flex gap-2 text-xs">
                            {g.out > 0 && <span className="text-red-600">{g.out} out</span>}
                            {g.low > 0 && <span className="text-amber-600">{g.low} low</span>}
                          </p>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-2">
                      {g.sizes.map((row) => (
                        <StockCell key={row.size} row={row} onSaved={onSaved} />
                      ))}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-right font-medium">{g.total}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </>
  );
};

export default Inventory;
