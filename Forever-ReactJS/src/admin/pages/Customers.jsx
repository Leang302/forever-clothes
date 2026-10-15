import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../../api/client";
import useApi from "../../components/useApi";
import { Card, ClearFilters, Empty, ErrorText, Loading, PageTitle, Pagination, SearchInput, Segmented, SortTh, Stat, StatusBadge } from "../components/ui";
import { formatDate, money } from "../format";
import { matches, paginate, sortRows, usePage, useSort } from "../table";

const ORDERS_PAGE_SIZE = 8;
const PAGE_SIZE = 10;
const shortDate = (iso) => new Date(iso).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
const HEADER_HEIGHT = 56; // the admin top bar is `sticky top-0 h-14`

/**
 * Keeps the filter bar stuck under the admin header. `sentinelRef` marks where the bar sits in the flow,
 * `barRef` is the bar itself. Returns whether it is stuck (for the shadow), its height (so the table header
 * can stick right below it) and `scrollToTop()`, which brings the list back to its top if it was scrolled past.
 */
function useStickyBar(ready) {
  const sentinelRef = useRef(null);
  const barRef = useRef(null);
  const [stuck, setStuck] = useState(false);
  const [barHeight, setBarHeight] = useState(0);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    const bar = barRef.current;
    if (!sentinel || !bar) return undefined;
    const onScroll = () => setStuck(sentinel.getBoundingClientRect().top < HEADER_HEIGHT);
    const ro = new ResizeObserver(() => setBarHeight(bar.offsetHeight));
    ro.observe(bar);
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    requestAnimationFrame(onScroll);
    return () => {
      ro.disconnect();
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', onScroll);
    };
  }, [ready]);

  const scrollToTop = useCallback(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel) return;
    const top = sentinel.getBoundingClientRect().top;
    if (top >= HEADER_HEIGHT) return; // list top is already in view
    const reduce = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    window.scrollTo({ top: window.scrollY + top - HEADER_HEIGHT, behavior: reduce ? 'auto' : 'smooth' });
  }, []);

  return { sentinelRef, barRef, stuck, barHeight, scrollToTop };
}

// Slide-over with one customer's details and paginated order history.
const CustomerPanel = ({ customer, onClose }) => {
  const [page, setPage] = useState(0);
  const { data, loading, error } = useApi(
    () => api.adminCustomerOrders(customer.id, { page, size: ORDERS_PAGE_SIZE }),
    [customer.id, page],
  );
  const orders = data?.content || [];
  const avg = customer.orderCount ? Number(customer.totalSpent) / customer.orderCount : 0;

  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  return (
    <>
      <div className="fixed inset-0 z-40 bg-black/30" onClick={onClose} />
      <aside
        role="dialog"
        aria-label={`${customer.name} details`}
        className="fixed top-0 right-0 z-50 h-full w-full sm:w-[28rem] bg-white shadow-xl flex flex-col"
      >
        <div className="flex items-start justify-between gap-3 p-5 border-b">
          <div className="min-w-0">
            <h2 className="text-lg font-medium truncate">{customer.name}</h2>
            <p className="text-sm text-gray-500 break-all">{customer.email}</p>
            <p className="text-sm text-gray-500">{customer.phone || 'No phone'}</p>
          </div>
          <button onClick={onClose} aria-label="Close" className="text-2xl leading-none text-gray-400 hover:text-black">
            ×
          </button>
        </div>

        <div className="grid grid-cols-3 gap-3 p-5 border-b text-center">
          <div>
            <p className="text-xs text-gray-500">Orders</p>
            <p className="text-lg font-medium">{customer.orderCount}</p>
          </div>
          <div>
            <p className="text-xs text-gray-500">Spent</p>
            <p className="text-lg font-medium">{money(customer.totalSpent)}</p>
          </div>
          <div>
            <p className="text-xs text-gray-500">Avg. order</p>
            <p className="text-lg font-medium">{money(avg)}</p>
          </div>
          <p className="col-span-3 text-xs text-gray-400">
            Customer since {shortDate(customer.createdAt)} · spent excludes cancelled orders
          </p>
        </div>

        <div className="flex-1 overflow-y-auto p-5">
          <h3 className="font-medium mb-3">Order history</h3>
          {loading && <Loading />}
          <ErrorText error={error} />
          {!loading && !error && orders.length === 0 && <Empty>No orders yet</Empty>}
          <ul className="flex flex-col gap-3">
            {orders.map((o) => (
              <li key={o.id} className="border rounded-lg p-3">
                <div className="flex items-center justify-between gap-2">
                  <Link to={`/admin/orders?q=${encodeURIComponent(`#${o.id}`)}`} className="font-medium hover:underline">
                    Order #{o.id}
                  </Link>
                  <StatusBadge status={o.status} />
                </div>
                <p className="text-xs text-gray-400 mt-1">
                  {formatDate(o.createdAt)} · {o.paymentMethod} · {o.paid ? 'Paid' : 'Unpaid'}
                </p>
                <div className="flex items-center justify-between mt-2">
                  <div className="flex -space-x-2">
                    {o.items.slice(0, 4).map((i, idx) => (
                      <img key={idx} src={i.image} alt={i.name} title={i.name} className="w-8 h-10 object-cover rounded border-2 border-white" />
                    ))}
                    {o.items.length > 4 && <span className="text-xs text-gray-500 pl-3 self-center">+{o.items.length - 4}</span>}
                  </div>
                  <span className="font-medium">{money(o.total)}</span>
                </div>
              </li>
            ))}
          </ul>
          <Pagination page={page} totalPages={data?.totalPages || 0} total={data?.totalElements} pageSize={data?.size} onChange={setPage} />
        </div>
      </aside>
    </>
  );
};

const Customers = () => {
  const { data, loading, error } = useApi(() => api.adminCustomers(), []);
  const [search, setSearch] = useState('');
  const [segment, setSegment] = useState('all');
  const [sort, onSort] = useSort('spent', 'desc', (key) => (key === 'name' ? 'asc' : 'desc'));
  const [selected, setSelected] = useState(null);

  const customers = useMemo(() => data || [], [data]);

  const visible = useMemo(() => {
    const filtered = customers.filter((c) => {
      if (!matches(search, c.name, c.email, c.phone)) return false;
      if (segment === 'buyers') return c.orderCount > 0;
      if (segment === 'none') return c.orderCount === 0;
      return true;
    });
    return sortRows(filtered, sort, {
      name: (c) => c.name,
      orders: (c) => c.orderCount,
      spent: (c) => Number(c.totalSpent),
      joined: (c) => new Date(c.createdAt).getTime(),
    });
  }, [customers, search, segment, sort]);
  const [page, setPage] = usePage(JSON.stringify([search, segment, sort]));
  const paged = paginate(visible, page, PAGE_SIZE);

  const stats = useMemo(() => {
    const buyers = customers.filter((c) => c.orderCount > 0);
    const revenue = customers.reduce((sum, c) => sum + Number(c.totalSpent), 0);
    return { buyers: buyers.length, revenue, avg: buyers.length ? revenue / buyers.length : 0 };
  }, [customers]);

  const { sentinelRef, barRef, stuck, barHeight, scrollToTop } = useStickyBar(!loading && !error);
  const activeFilters = (search.trim() ? 1 : 0) + (segment !== 'all' ? 1 : 0);
  const goToPage = (p) => {
    setPage(p);
    scrollToTop();
  };

  if (loading) return <Loading />;
  if (error) return <ErrorText error={error} />;

  return (
    <>
      <PageTitle title="Customers" />

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-3">
        <Stat label="Customers" value={customers.length} />
        <Stat label="Have ordered" value={stats.buyers} hint={`${customers.length - stats.buyers} never ordered`} />
        <Stat label="Customer revenue" value={money(stats.revenue)} hint="excluding cancelled" />
        <Stat label="Avg. per buyer" value={money(stats.avg)} />
      </div>

      {/* Filter bar sticks under the admin header (top-14) while the list scrolls; the table header sticks below it. */}
      <div ref={sentinelRef} aria-hidden="true" />
      <div
        ref={barRef}
        className={`sticky top-14 z-20 -mx-4 px-4 sm:-mx-6 sm:px-6 py-3 mb-1 bg-gray-50 border-b transition-shadow ${
          stuck ? 'border-gray-200 shadow-sm' : 'border-transparent'
        }`}
      >
        <div className="flex flex-wrap items-center gap-3">
          {stuck && <h2 className="hidden md:block font-medium">Customers</h2>}
          <SearchInput value={search} onChange={setSearch} placeholder="Search name, email or phone" />
          <Segmented
            value={segment}
            onChange={setSegment}
            options={[
              ['all', 'All'],
              ['buyers', 'With orders'],
              ['none', 'No orders'],
            ]}
          />
          <span className="text-sm text-gray-500">{visible.length} customers</span>
          {activeFilters > 0 && (
            <ClearFilters
              count={activeFilters}
              onClick={() => {
                setSearch('');
                setSegment('all');
              }}
            />
          )}
        </div>
      </div>

      {/* overflow-x-auto would make the card the scroll container and break the sticky table header, so it is only
          used on phones; from sm up the table fits and overflow-clip keeps the rounded corners without breaking sticky. */}
      <Card className="overflow-x-auto sm:overflow-clip">
        {visible.length === 0 ? (
          <Empty>No customers found</Empty>
        ) : (
          <table className="w-full text-sm">
            <thead
              className="sm:sticky z-10 bg-gray-50 text-gray-500 text-left shadow-[inset_0_-1px_0_rgb(229,231,235)]"
              style={{ top: HEADER_HEIGHT + barHeight }}
            >
              <tr>
                <SortTh label="Customer" sortKey="name" sort={sort} onSort={onSort} />
                <th className="px-4 py-3 font-normal hidden md:table-cell">Phone</th>
                <SortTh label="Orders" sortKey="orders" sort={sort} onSort={onSort} />
                <SortTh label="Spent" sortKey="spent" sort={sort} onSort={onSort} />
                <SortTh label="Joined" sortKey="joined" sort={sort} onSort={onSort} className="hidden sm:table-cell" />
              </tr>
            </thead>
            <tbody className="divide-y">
              {paged.rows.map((c) => (
                <tr
                  key={c.id}
                  onClick={() => setSelected(c)}
                  onKeyDown={(e) => e.key === 'Enter' && setSelected(c)}
                  tabIndex={0}
                  className="cursor-pointer hover:bg-gray-50 focus:bg-gray-50 outline-none"
                >
                  <td className="px-4 py-3">
                    <p className="font-medium">{c.name}</p>
                    <p className="text-xs text-gray-400 break-all">{c.email}</p>
                  </td>
                  <td className="px-4 py-3 hidden md:table-cell">{c.phone || <span className="text-gray-400">—</span>}</td>
                  <td className="px-4 py-3">{c.orderCount}</td>
                  <td className="px-4 py-3 font-medium">{money(c.totalSpent)}</td>
                  <td className="px-4 py-3 hidden sm:table-cell text-gray-500">{shortDate(c.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
      <Pagination page={paged.page} totalPages={paged.totalPages} total={paged.total} pageSize={paged.pageSize} onChange={goToPage} />

      {selected && <CustomerPanel key={selected.id} customer={selected} onClose={() => setSelected(null)} />}
    </>
  );
};

export default Customers;
