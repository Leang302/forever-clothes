import { useContext, useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { ShopContext } from "../context/ShopContext";
import { assets } from "../assets/frontend_assets/assets";
import { api } from "../api/client";
import Title from "../components/Title";
import ProductGridSection from "../components/ProductGridSection";

const PAGE_SIZE = 20;
const SORTS = { relevant: 'relevant', 'low-high': 'price_asc', 'high-low': 'price_desc' };
const SEARCH_DELAY = 300;

const toggle = (list, value) => (list.includes(value) ? list.filter((v) => v !== value) : [...list, value]);
const listParam = (params, key) => (params.get(key) ? params.get(key).split(',') : []);

const Collection = () => {
  const { search, setSearch, showSearch } = useContext(ShopContext);
  const [showFilter, setShowFilter] = useState(false);
  // Filters and sort live in the URL, so refresh, back/forward and shared links keep them.
  const [params, setParams] = useSearchParams();
  const category = listParam(params, 'category');
  const subCategory = listParam(params, 'sub');
  const sortType = SORTS[params.get('sort')] ? params.get('sort') : 'relevant';
  const setParam = (key, value) =>
    setParams(
      (prev) => {
        const next = new URLSearchParams(prev);
        const v = Array.isArray(value) ? value.join(',') : value;
        if (!v || (key === 'sort' && v === 'relevant')) next.delete(key);
        else next.set(key, v);
        return next;
      },
      { replace: true },
    );
  const [options, setOptions] = useState({ categories: ['Men', 'Women', 'Kids'], subCategories: ['Topwear', 'Bottomwear', 'Winterwear'] });

  const [items, setItems] = useState([]);
  const [total, setTotal] = useState(null);
  const [page, setPage] = useState(0);
  const [last, setLast] = useState(true);
  const [firstLoad, setFirstLoad] = useState(true); // only the very first load replaces the grid
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);

  const q = showSearch ? search.trim() : '';
  const filterKey = JSON.stringify([q, category, subCategory, sortType]);

  useEffect(() => {
    api.filters().then(setOptions).catch(() => {});
  }, []);

  // Reload from page 0 whenever a filter, the sort or the search changes. Typing waits for a pause; the
  // current products stay visible (dimmed) until the new ones arrive.
  useEffect(() => {
    let cancelled = false;
    const timer = setTimeout(() => {
      setRefreshing(true);
      setError(null);
      api.products({ q, category, subCategory, sort: SORTS[sortType], page: 0, size: PAGE_SIZE })
        .then((res) => {
          if (cancelled) return;
          setItems(res.content);
          setTotal(res.totalElements);
          setPage(0);
          setLast(res.last);
        })
        .catch((e) => !cancelled && setError(e))
        .finally(() => {
          if (cancelled) return;
          setRefreshing(false);
          setFirstLoad(false);
        });
    }, q ? SEARCH_DELAY : 0);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- filterKey covers q, category, subCategory, sortType
  }, [filterKey]);

  const [loadingMore, setLoadingMore] = useState(false);
  const loadMore = async () => {
    setLoadingMore(true);
    try {
      const res = await api.products({ q, category, subCategory, sort: SORTS[sortType], page: page + 1, size: PAGE_SIZE });
      setItems((prev) => [...prev, ...res.content]);
      setPage(res.page);
      setLast(res.last);
    } catch (e) {
      setError(e);
    } finally {
      setLoadingMore(false);
    }
  };

  const chips = [
    ...(q ? [{ key: 'q', label: `"${q}"`, remove: () => setSearch('') }] : []),
    ...category.map((c) => ({ key: `c-${c}`, label: c, remove: () => setParam('category', category.filter((x) => x !== c)) })),
    ...subCategory.map((s) => ({ key: `s-${s}`, label: s, remove: () => setParam('sub', subCategory.filter((x) => x !== s)) })),
  ];
  const clearAll = () => {
    setSearch('');
    setParams((prev) => {
      const next = new URLSearchParams(prev);
      ['category', 'sub'].forEach((k) => next.delete(k));
      return next;
    }, { replace: true });
  };

  const checkboxGroup = (title, values, selected, key) => (
    <div className={`border border-gray-300 pl-5 py-3 mt-5 ${showFilter ? "" : "hidden"} sm:block`}>
      <p className="mb-3 text-sm font-medium uppercase">{title}</p>
      <div className="flex flex-col gap-2 text-sm font-light text-gray-700">
        {values.map((item) => (
          <label key={item} className="gap-2 flex cursor-pointer">
            <input type="checkbox" className="w-3" checked={selected.includes(item)} onChange={() => setParam(key, toggle(selected, item))} /> {item}
          </label>
        ))}
      </div>
    </div>
  );

  return (
    <div className="flex flex-col sm:flex-row gap-1 sm:gap-10 pt-10 border-t">
      {/* Filter Options */}
      <div className="min-w-60">
        <p className="my-2 text-xl flex items-center gap-2 cursor-pointer hover:underline hover:transition-all" onClick={() => setShowFilter((s) => !s)}>
          FILTER
          {chips.length > 0 && <span className="rounded-full bg-black px-2 text-xs text-white">{chips.length}</span>}
          <img className={`h-3 sm:hidden ${showFilter ? 'rotate-90' : ''}`} src={assets.dropdown_icon} alt="Toggle Filter" />
        </p>
        <div className="sm:sticky sm:top-4">
          {checkboxGroup('Categories', options.categories, category, 'category')}
          {checkboxGroup('Sub category', options.subCategories, subCategory, 'sub')}
        </div>
      </div>
      {/* Product Section */}
      <div className="flex-1">
        <div className="flex justify-between text-base sm:text-2xl mb-3">
          <Title text1={'ALL'} text2={'Collection'} />
          <select value={sortType} onChange={(e) => setParam('sort', e.target.value)} aria-label="Sort products" className="border border-gray-300 text-sm px-2">
            <option value="relevant">Sort by: Relevant</option>
            <option value="low-high">Sort by: Low to High</option>
            <option value="high-low">Sort by: High to Low</option>
          </select>
        </div>

        <div className="mb-5 flex min-h-8 flex-wrap items-center gap-2 text-sm">
          {total != null && (
            <span className="text-gray-500">
              {total} {total === 1 ? 'product' : 'products'}
            </span>
          )}
          {refreshing && !firstLoad && <span className="text-gray-400">· Updating…</span>}
          {chips.map((chip) => (
            <button
              key={chip.key}
              type="button"
              onClick={chip.remove}
              className="inline-flex items-center gap-1.5 rounded-full border border-gray-300 px-3 py-1 text-gray-700 hover:border-black"
              aria-label={`Remove filter ${chip.label}`}
            >
              {chip.label} <span aria-hidden="true">×</span>
            </button>
          ))}
          {chips.length > 1 && (
            <button type="button" onClick={clearAll} className="text-gray-500 underline hover:text-black">
              Clear all
            </button>
          )}
        </div>

        <ProductGridSection
          products={items}
          loading={firstLoad}
          error={error}
          refreshing={refreshing && !firstLoad}
          cols="grid-cols-2 md:grid-cols-3 lg:grid-cols-4"
        />
        {!firstLoad && !refreshing && !error && items.length === 0 && (
          <div className="py-10 text-center text-gray-500">
            <p>No products match these filters.</p>
            {chips.length > 0 && (
              <button type="button" onClick={clearAll} className="mt-3 underline hover:text-black">
                Clear filters
              </button>
            )}
          </div>
        )}
        {!firstLoad && !last && (
          <div className="text-center mt-10">
            <button onClick={loadMore} disabled={loadingMore} className="border border-black px-8 py-3 text-sm hover:bg-black hover:text-white transition-all disabled:opacity-50">
              {loadingMore ? 'Loading...' : 'Load more'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default Collection;
