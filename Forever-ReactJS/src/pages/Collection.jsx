import { useContext, useEffect, useState } from "react";
import { ShopContext } from "../context/ShopContext";
import { assets } from "../assets/frontend_assets/assets";
import { api } from "../api/client";
import Title from "../components/Title";
import ProductGridSection from "../components/ProductGridSection";

const PAGE_SIZE = 20;
const SORTS = { relevant: 'relevant', 'low-high': 'price_asc', 'high-low': 'price_desc' };

const toggle = (list, value) => (list.includes(value) ? list.filter((v) => v !== value) : [...list, value]);

const Collection = () => {
  const { search, showSearch } = useContext(ShopContext);
  const [showFilter, setShowFilter] = useState(false);
  const [category, setCategory] = useState([]);
  const [subCategory, setSubCategory] = useState([]);
  const [sortType, setSortType] = useState('relevant');
  const [options, setOptions] = useState({ categories: ['Men', 'Women', 'Kids'], subCategories: ['Topwear', 'Bottomwear', 'Winterwear'] });

  const [items, setItems] = useState([]);
  const [page, setPage] = useState(0);
  const [last, setLast] = useState(true);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const q = showSearch ? search : '';

  useEffect(() => {
    api.filters().then(setOptions).catch(() => {});
  }, []);

  // Reload from page 0 whenever a filter, the sort or the (debounced) search changes.
  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    const timer = setTimeout(() => {
      api.products({ q, category, subCategory, sort: SORTS[sortType], page: 0, size: PAGE_SIZE })
        .then((res) => {
          if (cancelled) return;
          setItems(res.content);
          setPage(0);
          setLast(res.last);
        })
        .catch((e) => !cancelled && setError(e))
        .finally(() => !cancelled && setLoading(false));
    }, q ? 300 : 0);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [q, category, subCategory, sortType]);

  const loadMore = async () => {
    try {
      const res = await api.products({ q, category, subCategory, sort: SORTS[sortType], page: page + 1, size: PAGE_SIZE });
      setItems((prev) => [...prev, ...res.content]);
      setPage(res.page);
      setLast(res.last);
    } catch (e) {
      setError(e);
    }
  };

  return (
    <div className="flex flex-col sm:flex-row gap-1 sm:gap-10 pt-10 border-t">
      {/* Filter Options */}
      <div className="min-w-60">
        <p className="my-2 text-xl flex items-center gap-2 cursor-pointer hover:underline hover:transition-all" onClick={() => setShowFilter((s) => !s)}>
          FILTER
          <img className={`h-3 sm:hidden ${showFilter ? 'rotate-90' : ''}`} src={assets.dropdown_icon} alt="Toggle Filter" />
        </p>
        <div className={`border border-gray-300 pl-5 py-3 mt-6 ${showFilter ? "" : "hidden"} sm:block`}>
          <p className="mb-3 text-sm font-medium uppercase">Categories</p>
          <div className="flex flex-col gap-2 text-sm font-light text-gray-700">
            {options.categories.map((item) => (
              <label key={item} className="gap-2 flex cursor-pointer">
                <input type="checkbox" className="w-3" checked={category.includes(item)} onChange={() => setCategory((c) => toggle(c, item))} /> {item}
              </label>
            ))}
          </div>
        </div>
        <div className={`border border-gray-300 pl-5 py-3 my-5 ${showFilter ? "" : "hidden"} sm:block`}>
          <p className="mb-3 text-sm font-medium uppercase">Type</p>
          <div className="flex flex-col gap-2 text-sm font-light text-gray-700">
            {options.subCategories.map((item) => (
              <label key={item} className="gap-2 flex cursor-pointer">
                <input type="checkbox" className="w-3" checked={subCategory.includes(item)} onChange={() => setSubCategory((c) => toggle(c, item))} /> {item}
              </label>
            ))}
          </div>
        </div>
      </div>
      {/* Product Section */}
      <div className="flex-1">
        <div className="flex justify-between text-base sm:text-2xl mb-4">
          <Title text1={'ALL'} text2={'Collection'} />
          <select value={sortType} onChange={(e) => setSortType(e.target.value)} className="border border-gray-300 text-sm px-2">
            <option value="relevant">Sort by: Relevant</option>
            <option value="low-high">Sort by: Low to High</option>
            <option value="high-low">Sort by: High to Low</option>
          </select>
        </div>
        <ProductGridSection products={items} loading={loading} error={error} cols="grid-cols-2 md:grid-cols-3 lg:grid-cols-4" />
        {!loading && !error && items.length === 0 && <p className="text-center text-gray-500 py-10">No products found</p>}
        {!loading && !last && (
          <div className="text-center mt-10">
            <button onClick={loadMore} className="border border-black px-8 py-3 text-sm hover:bg-black hover:text-white transition-all">Load more</button>
          </div>
        )}
      </div>
    </div>
  );
};

export default Collection;
