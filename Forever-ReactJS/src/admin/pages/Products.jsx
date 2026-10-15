import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import useApi from "../../components/useApi";
import { Card, Empty, ErrorText, Loading, MultiSelect, PageTitle, Pagination, SearchInput, Segmented, SortTh } from "../components/ui";
import { money } from "../format";
import { useDebounced, usePage, useSort } from "../table";

const PAGE_SIZE = 10;
const LOW_STOCK = 5;

// Table sort state -> API `sort` value.
const toApiSort = ({ key, dir }) => (key === 'date' ? (dir === 'desc' ? 'newest' : 'oldest') : `${key}_${dir}`);

const Products = () => {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const debounced = useDebounced(search);
  const [categories, setCategories] = useState([]);
  const [visibility, setVisibility] = useState('all');
  const [sort, onSort, setSort] = useSort('date', 'desc', (key) => (key === 'name' ? 'asc' : 'desc'));
  const [version, setVersion] = useState(0);
  const [categoryOptions, setCategoryOptions] = useState([]);
  const [stock, setStock] = useState({});

  useEffect(() => {
    Promise.all([api.filters().catch(() => ({ categories: [] })), api.adminCategories().catch(() => [])]).then(([f, managed]) =>
      setCategoryOptions([...new Set([...managed.map((c) => c.name), ...f.categories])].sort()),
    );
  }, []);

  // Total stock and low/out sizes per product, from the inventory list.
  useEffect(() => {
    api
      .adminInventory()
      .then((rows) => {
        const byId = {};
        rows.forEach((r) => {
          const s = (byId[r.productId] ??= { total: 0, low: 0, out: 0 });
          s.total += r.stock;
          if (r.stock === 0) s.out += 1;
          else if (r.stock <= LOW_STOCK) s.low += 1;
        });
        setStock(byId);
      })
      .catch(() => {});
  }, [version]);

  // Any filter change goes back to the first page.
  const [page, setPage] = usePage(JSON.stringify([debounced, categories, visibility, sort]));

  const { data, loading, error } = useApi(
    () =>
      api.adminProducts({
        q: debounced,
        category: categories,
        active: visibility === 'all' ? undefined : visibility === 'visible',
        sort: toApiSort(sort),
        page,
        size: PAGE_SIZE,
      }),
    [debounced, categories, visibility, sort, page, version],
  );

  const toggle = async (p) => {
    try {
      await api.adminSetProductActive(p.id, !p.active);
      toast.success(p.active ? `"${p.name}" is now hidden from the shop` : `"${p.name}" is visible in the shop`);
      setVersion((v) => v + 1);
    } catch (e) {
      toast.error(e.message);
    }
  };

  const items = data?.content || [];
  const filtered = debounced || categories.length || visibility !== 'all';
  const clearFilters = () => {
    setSearch('');
    setCategories([]);
    setVisibility('all');
  };

  return (
    <>
      <PageTitle title="Products">
        <Link to="/admin/products/new" className="bg-black text-white text-sm px-4 py-2 rounded">
          + Add product
        </Link>
      </PageTitle>

      <div className="flex flex-wrap items-center gap-3 mb-4">
        <SearchInput value={search} onChange={setSearch} placeholder="Search name or #id" />
        <MultiSelect label="Categories" options={categoryOptions} value={categories} onChange={setCategories} />
        <Segmented
          value={visibility}
          onChange={setVisibility}
          options={[
            ['all', 'All'],
            ['visible', 'Visible'],
            ['hidden', 'Hidden'],
          ]}
        />
        <select
          value={toApiSort(sort)}
          onChange={(e) => {
            const v = e.target.value;
            if (v === 'newest' || v === 'oldest') setSort({ key: 'date', dir: v === 'newest' ? 'desc' : 'asc' });
            else {
              const i = v.lastIndexOf('_');
              setSort({ key: v.slice(0, i), dir: v.slice(i + 1) });
            }
          }}
          aria-label="Sort products"
          className="border border-gray-300 rounded px-3 py-2 text-sm bg-white"
        >
          <option value="newest">Newest first</option>
          <option value="oldest">Oldest first</option>
          <option value="name_asc">Name A–Z</option>
          <option value="name_desc">Name Z–A</option>
          <option value="price_asc">Price: low to high</option>
          <option value="price_desc">Price: high to low</option>
          <option value="stock_asc">Stock: low to high</option>
          <option value="stock_desc">Stock: high to low</option>
        </select>
        {data && <span className="text-sm text-gray-500">{data.totalElements} products</span>}
        {filtered && (
          <button onClick={clearFilters} className="text-sm text-gray-500 underline hover:text-black">
            Clear filters
          </button>
        )}
      </div>

      <Card className="overflow-x-auto">
        {loading && <Loading />}
        <ErrorText error={error} />
        {!loading && !error && items.length === 0 && <Empty>No products found</Empty>}

        {!loading && items.length > 0 && (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-left">
              <tr>
                <SortTh label="Product" sortKey="name" sort={sort} onSort={onSort} />
                <th className="px-4 py-3 font-normal hidden md:table-cell">Category</th>
                <SortTh label="Price" sortKey="price" sort={sort} onSort={onSort} />
                <SortTh label="Stock" sortKey="stock" sort={sort} onSort={onSort} className="hidden sm:table-cell" />
                <th className="px-4 py-3 font-normal">Visible</th>
                <th className="px-4 py-3 font-normal text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {items.map((p) => {
                const s = stock[p.id];
                return (
                  <tr key={p.id} className={p.active ? '' : 'bg-gray-50 text-gray-400'}>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-3">
                        <img src={p.images[0]} alt="" className={`w-12 h-14 object-cover rounded ${p.active ? '' : 'opacity-50'}`} />
                        <div className="min-w-0">
                          <p className="font-medium truncate max-w-[14rem]">{p.name}</p>
                          <p className="text-xs text-gray-400">
                            #{p.id} · {p.sizes.join(', ')}
                            {p.bestseller ? ' · ★ Bestseller' : ''}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 hidden md:table-cell">
                      {p.category} · {p.subCategory}
                    </td>
                    <td className="px-4 py-3">{money(p.price)}</td>
                    <td className="px-4 py-3 hidden sm:table-cell">
                      {s ? (
                        <>
                          <span className={s.total === 0 ? 'text-red-600 font-medium' : ''}>{s.total}</span>
                          {(s.out > 0 || s.low > 0) && (
                            <Link to="/admin/inventory" className="block text-xs hover:underline">
                              {s.out > 0 && <span className="text-red-600">{s.out} out </span>}
                              {s.low > 0 && <span className="text-amber-600">{s.low} low</span>}
                            </Link>
                          )}
                        </>
                      ) : (
                        <span className="text-gray-400">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <button
                        onClick={() => toggle(p)}
                        role="switch"
                        aria-checked={p.active}
                        aria-label={`${p.active ? 'Hide' : 'Show'} ${p.name}`}
                        className={`relative w-10 h-6 rounded-full transition-colors ${p.active ? 'bg-black' : 'bg-gray-300'}`}
                      >
                        <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white transition-transform ${p.active ? 'translate-x-4' : ''}`} />
                      </button>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        onClick={() => navigate(`/admin/products/${p.id}/edit`)}
                        className="border border-gray-300 rounded px-3 py-1 text-gray-700 hover:bg-gray-100 bg-white"
                      >
                        Edit
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>

      <Pagination page={page} totalPages={data?.totalPages || 0} onChange={setPage} />
    </>
  );
};

export default Products;
