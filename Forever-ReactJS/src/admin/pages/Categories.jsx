import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import useApi from "../../components/useApi";
import { Card, ConfirmDelete, Empty, ErrorText, Loading, PageTitle, Pagination, SearchInput, Segmented } from "../components/ui";
import { money } from "../format";
import { matches, sortRows, useDebounced, usePage } from "../table";

const PAGE_SIZE = 8;

// Products belonging to one category, with search, visibility filter, sorting and links to edit each one.
const CategoryProducts = ({ category }) => {
  const [search, setSearch] = useState('');
  const debounced = useDebounced(search);
  const [visibility, setVisibility] = useState('all');
  const [sort, setSort] = useState('newest');
  const [page, setPage] = usePage(JSON.stringify([debounced, visibility, sort]));

  const { data, loading, error } = useApi(
    () =>
      api.adminProducts({
        category: category.name,
        q: debounced.trim() || undefined,
        active: visibility === 'all' ? undefined : visibility === 'visible',
        sort,
        page,
        size: PAGE_SIZE,
      }),
    [category.name, debounced, visibility, sort, page],
  );
  const items = data?.content || [];

  return (
    <Card className="overflow-hidden">
      <div className="flex flex-wrap items-center justify-between gap-3 p-4 border-b">
        <div>
          <h2 className="font-medium">{category.name}</h2>
          {data && <p className="text-xs text-gray-500">{data.totalElements} matching products</p>}
        </div>
        <Link to="/admin/products/new" className="bg-black text-white text-sm px-4 py-2 rounded whitespace-nowrap">
          + Add product
        </Link>
      </div>

      <div className="flex flex-wrap items-center gap-2 p-4 border-b bg-gray-50">
        <SearchInput value={search} onChange={setSearch} placeholder={`Search in ${category.name}`} className="w-full sm:w-56" />
        <Segmented
          value={visibility}
          onChange={setVisibility}
          options={[
            ['all', 'All'],
            ['visible', 'Visible'],
            ['hidden', 'Hidden'],
          ]}
        />
        <select value={sort} onChange={(e) => setSort(e.target.value)} aria-label="Sort products" className="border border-gray-300 rounded px-3 py-2 text-sm bg-white">
          <option value="newest">Newest</option>
          <option value="name_asc">Name A–Z</option>
          <option value="price_asc">Price: low to high</option>
          <option value="price_desc">Price: high to low</option>
          <option value="stock_asc">Stock: low to high</option>
        </select>
      </div>

      {loading && <Loading />}
      <ErrorText error={error} />
      {!loading && !error && items.length === 0 && (
        <Empty>{debounced || visibility !== 'all' ? 'No matching products' : 'No products in this category yet'}</Empty>
      )}

      {!loading && items.length > 0 && (
        <ul className="divide-y">
          {items.map((p) => (
            <li key={p.id} className={`flex items-center gap-3 px-4 py-3 ${p.active ? '' : 'bg-gray-50'}`}>
              <img src={p.images[0]} alt="" className={`w-12 h-14 object-cover rounded shrink-0 ${p.active ? '' : 'opacity-50'}`} />
              <div className="min-w-0 flex-1">
                <p className={`font-medium truncate ${p.active ? '' : 'text-gray-400'}`}>{p.name}</p>
                <p className="text-xs text-gray-400">
                  #{p.id} · {p.subCategory} · {money(p.price)}
                </p>
              </div>
              <span
                className={`hidden sm:inline-block px-2.5 py-1 rounded-full text-xs font-medium ${
                  p.active ? 'bg-green-100 text-green-700' : 'bg-gray-200 text-gray-600'
                }`}
              >
                {p.active ? 'Visible' : 'Hidden'}
              </span>
              <Link
                to={`/admin/products/${p.id}/edit`}
                className="border border-gray-300 rounded px-3 py-1 text-sm text-gray-700 hover:bg-gray-100 bg-white"
              >
                Edit
              </Link>
            </li>
          ))}
        </ul>
      )}

      <div className="px-4 pb-4">
        <Pagination page={page} totalPages={data?.totalPages || 0} onChange={setPage} />
      </div>
    </Card>
  );
};

const Categories = () => {
  const [version, setVersion] = useState(0);
  const [name, setName] = useState('');
  const [saving, setSaving] = useState(false);
  const [selectedId, setSelectedId] = useState(null);
  const [filter, setFilter] = useState('');
  const [order, setOrder] = useState('name');

  const { data, loading, error } = useApi(() => api.adminCategories(), [version]);

  const categories = useMemo(() => {
    const list = (data || []).filter((c) => matches(filter, c.name));
    return order === 'name'
      ? sortRows(list, { key: 'name', dir: 'asc' }, { name: (c) => c.name })
      : sortRows(list, { key: 'count', dir: 'desc' }, { count: (c) => c.productCount ?? 0 });
  }, [data, filter, order]);
  const selected = (data || []).find((c) => c.id === selectedId) || categories[0];

  const addCategory = async (e) => {
    e.preventDefault();
    const trimmed = name.trim();
    if (!trimmed) return;
    setSaving(true);
    try {
      const created = await api.adminAddCategory(trimmed);
      toast.success(`Category "${created.name}" added`);
      setName('');
      setSelectedId(created.id);
      setVersion((v) => v + 1);
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSaving(false);
    }
  };

  const deleteCategory = async (c) => {
    try {
      await api.adminDeleteCategory(c.id);
      toast.success(`Category "${c.name}" deleted`);
      if (selectedId === c.id) setSelectedId(null);
      setVersion((v) => v + 1);
    } catch (err) {
      toast.error(err.message);
    }
  };

  return (
    <>
      <PageTitle title="Categories">
        {data && <span className="text-sm text-gray-500">{data.length} categories</span>}
      </PageTitle>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="flex flex-col gap-4 min-w-0">
          <Card className="p-4">
            <form onSubmit={addCategory}>
              <label htmlFor="category-name" className="block text-sm text-gray-600 mb-1">
                New category
              </label>
              <div className="flex gap-2">
                <input
                  id="category-name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  maxLength={40}
                  required
                  placeholder="e.g. Accessories"
                  className="border border-gray-300 rounded px-3 py-2 text-sm bg-white flex-1 min-w-0"
                />
                <button disabled={saving || !name.trim()} className="bg-black text-white text-sm px-4 py-2 rounded disabled:opacity-50">
                  {saving ? 'Adding...' : 'Add'}
                </button>
              </div>
              <p className="text-xs text-gray-400 mt-2">New categories appear as suggestions in the product form.</p>
            </form>
          </Card>

          <Card className="overflow-hidden">
            <div className="flex items-center gap-2 p-3 border-b">
              <SearchInput value={filter} onChange={setFilter} placeholder="Filter categories" className="flex-1" />
              <select value={order} onChange={(e) => setOrder(e.target.value)} aria-label="Sort categories" className="border border-gray-300 rounded px-2 py-2 text-sm bg-white">
                <option value="name">A–Z</option>
                <option value="count">Most products</option>
              </select>
            </div>
            {loading && <Loading />}
            <ErrorText error={error} />
            {!loading && !error && categories.length === 0 && <Empty>{data?.length ? 'No match' : 'No categories yet'}</Empty>}
            {categories.length > 0 && (
              <ul className="divide-y">
                {categories.map((c) => {
                  const isSelected = selected?.id === c.id;
                  const hasCount = c.productCount !== undefined;
                  const hidden = hasCount ? c.productCount - c.activeProductCount : 0;
                  return (
                    <li key={c.id} className={`flex items-center gap-2 px-4 py-3 ${isSelected ? 'bg-gray-100' : 'hover:bg-gray-50'}`}>
                      <button type="button" onClick={() => setSelectedId(c.id)} className="flex-1 min-w-0 text-left">
                        <p className="font-medium truncate">{c.name}</p>
                        {hasCount && (
                          <p className="text-xs text-gray-500">
                            {c.productCount} {c.productCount === 1 ? 'product' : 'products'}
                            {hidden > 0 && ` · ${hidden} hidden`}
                          </p>
                        )}
                      </button>
                      {hasCount && c.productCount > 0 ? (
                        <span className="text-xs text-gray-400" title="Move or delete its products before deleting this category">
                          In use
                        </span>
                      ) : (
                        <ConfirmDelete onConfirm={() => deleteCategory(c)} />
                      )}
                    </li>
                  );
                })}
              </ul>
            )}
          </Card>
        </div>

        <div className="lg:col-span-2 min-w-0">
          {selected ? (
            <CategoryProducts key={selected.id} category={selected} />
          ) : (
            !loading && (
              <Card>
                <Empty>Select a category to see its products</Empty>
              </Card>
            )
          )}
        </div>
      </div>
    </>
  );
};

export default Categories;
