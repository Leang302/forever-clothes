import { Fragment, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import useApi from "../../components/useApi";
import { Card, Empty, ErrorText, Loading, PageTitle, Pagination, SearchInput, Segmented, SortTh, StatusBadge } from "../components/ui";
import { STATUSES, formatDate, money } from "../format";
import { useDebounced, usePage, useSort } from "../table";

const PAGE_SIZE = 10;
const PAYMENT_METHODS = [
  ['COD', 'Cash on delivery'],
  ['PAYWAY', 'ABA PayWay'],
];
const statusLabel = (value) => STATUSES.find(([v]) => v === value)?.[1] || value;

// Table sort state -> API `sort` value.
const toApiSort = ({ key, dir }) => {
  if (key === 'total') return dir === 'asc' ? 'total_asc' : 'total_desc';
  if (key === 'status') return 'status';
  return dir === 'asc' ? 'oldest' : 'newest';
};

// Statuses the admin may pick for this order. Falls back to every status for older API responses without `nextStatuses`.
const nextOptions = (o) => {
  if (Array.isArray(o.nextStatuses)) return o.nextStatuses;
  if (o.status === 'CANCELLED' || o.status === 'DELIVERED') return [];
  return STATUSES.map(([v]) => v).filter((v) => v !== o.status);
};

const Orders = () => {
  const [params, setParams] = useSearchParams();
  const [search, setSearchState] = useState(params.get('q') || '');
  const debounced = useDebounced(search);
  const [status, setStatus] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('');
  const [paid, setPaid] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [sort, onSort] = useSort('date', 'desc', (key) => (key === 'status' ? 'asc' : 'desc'));
  const [page, setPage] = usePage(JSON.stringify([debounced, status, paymentMethod, paid, from, to, sort]));
  const [version, setVersion] = useState(0);
  const [openId, setOpenId] = useState(null);
  const [updating, setUpdating] = useState(null);

  const setSearch = (value) => {
    setSearchState(value);
    if (params.get('q')) setParams({}, { replace: true });
  };

  const { data, loading, error } = useApi(
    () =>
      api.adminOrders({
        q: debounced.trim() || undefined,
        status: status || undefined,
        paymentMethod: paymentMethod || undefined,
        paid: paid === '' ? undefined : paid === 'paid',
        from: from || undefined,
        to: to || undefined,
        sort: toApiSort(sort),
        page,
        size: PAGE_SIZE,
      }),
    [debounced, status, paymentMethod, paid, from, to, sort, page, version],
  );

  const changeStatus = async (order, next) => {
    if (next === order.status) return;
    setUpdating(order.id);
    try {
      await api.adminUpdateOrderStatus(order.id, next);
      toast.success(`Order #${order.id} is now "${statusLabel(next)}"`);
      setVersion((v) => v + 1);
    } catch (e) {
      toast.error(e.message);
    } finally {
      setUpdating(null);
    }
  };

  const orders = data?.content || [];
  const filtered = debounced || status || paymentMethod || paid || from || to;
  const clearFilters = () => {
    setSearch('');
    setStatus('');
    setPaymentMethod('');
    setPaid('');
    setFrom('');
    setTo('');
  };

  return (
    <>
      <PageTitle title="Orders">
        {data && <span className="text-sm text-gray-500">{data.totalElements} orders</span>}
      </PageTitle>

      <div className="flex flex-wrap gap-2 mb-3">
        {[['', 'All'], ...STATUSES.map(([v, l]) => [v, l])].map(([value, label]) => (
          <button
            key={value}
            onClick={() => setStatus(value)}
            className={`px-3 py-1.5 rounded-full text-sm border ${
              status === value ? 'bg-black text-white border-black' : 'bg-white border-gray-300 text-gray-600 hover:bg-gray-100'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-end gap-3 mb-4">
        <SearchInput value={search} onChange={setSearch} placeholder="Order #, customer name, email or phone" className="w-full sm:w-80" />
        <select
          value={paymentMethod}
          onChange={(e) => setPaymentMethod(e.target.value)}
          aria-label="Payment method"
          className="border border-gray-300 rounded px-3 py-2 text-sm bg-white"
        >
          <option value="">All payment methods</option>
          {PAYMENT_METHODS.map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
        <Segmented
          value={paid}
          onChange={setPaid}
          options={[
            ['', 'Any'],
            ['paid', 'Paid'],
            ['unpaid', 'Unpaid'],
          ]}
        />
        <label className="flex flex-col text-xs text-gray-500">
          From
          <input type="date" value={from} max={to || undefined} onChange={(e) => setFrom(e.target.value)} className="border border-gray-300 rounded px-2 py-1.5 text-sm bg-white text-gray-800" />
        </label>
        <label className="flex flex-col text-xs text-gray-500">
          To
          <input type="date" value={to} min={from || undefined} onChange={(e) => setTo(e.target.value)} className="border border-gray-300 rounded px-2 py-1.5 text-sm bg-white text-gray-800" />
        </label>
        {filtered && (
          <button onClick={clearFilters} className="text-sm text-gray-500 underline hover:text-black pb-2">
            Clear filters
          </button>
        )}
      </div>

      <Card className="overflow-x-auto">
        {loading && <Loading />}
        <ErrorText error={error} />
        {!loading && !error && orders.length === 0 && <Empty>No orders found</Empty>}

        {!loading && orders.length > 0 && (
          <table className="w-full text-sm">
            <thead className="bg-gray-50 text-gray-500 text-left">
              <tr>
                <SortTh label="Order" sortKey="date" sort={sort} onSort={onSort} />
                <th className="px-4 py-3 font-normal hidden md:table-cell">Customer</th>
                <th className="px-4 py-3 font-normal hidden lg:table-cell">Payment</th>
                <SortTh label="Total" sortKey="total" sort={sort} onSort={onSort} />
                <SortTh label="Status" sortKey="status" sort={sort} onSort={onSort} />
              </tr>
            </thead>
            <tbody>
              {orders.map((o) => {
                const options = nextOptions(o);
                return (
                  <Fragment key={o.id}>
                    <tr className="border-t hover:bg-gray-50 cursor-pointer" onClick={() => setOpenId(openId === o.id ? null : o.id)}>
                      <td className="px-4 py-3">
                        <p className="font-medium">#{o.id}</p>
                        <p className="text-xs text-gray-400">{formatDate(o.createdAt)}</p>
                      </td>
                      <td className="px-4 py-3 hidden md:table-cell">
                        <p>
                          {o.address.firstName} {o.address.lastName}
                        </p>
                        <p className="text-xs text-gray-400">
                          {o.address.city}, {o.address.country}
                        </p>
                      </td>
                      <td className="px-4 py-3 hidden lg:table-cell">
                        {o.paymentMethod}{' '}
                        <span className={o.paid ? 'text-green-600' : 'text-gray-400'}>· {o.paid ? 'Paid' : 'Unpaid'}</span>
                      </td>
                      <td className="px-4 py-3 font-medium">
                        {money(o.total)}
                        {o.couponCode && <p className="text-xs font-normal text-gray-400">{o.couponCode}</p>}
                      </td>
                      <td className="px-4 py-3" onClick={(e) => e.stopPropagation()}>
                        {options.length === 0 ? (
                          <StatusBadge status={o.status} />
                        ) : (
                          <select
                            value={o.status}
                            disabled={updating === o.id}
                            onChange={(e) => changeStatus(o, e.target.value)}
                            aria-label={`Status of order ${o.id}`}
                            className="border border-gray-300 rounded px-2 py-1.5 bg-white text-sm"
                          >
                            <option value={o.status} disabled>
                              {statusLabel(o.status)}
                            </option>
                            {options.map((v) => (
                              <option key={v} value={v}>
                                → {statusLabel(v)}
                              </option>
                            ))}
                          </select>
                        )}
                      </td>
                    </tr>
                    {openId === o.id && (
                      <tr className="bg-gray-50">
                        <td colSpan={5} className="px-4 py-4">
                          <div className="grid md:grid-cols-2 gap-6">
                            <div className="flex flex-col gap-3">
                              {o.items.map((i, idx) => (
                                <div key={idx} className="flex items-center gap-3">
                                  <img src={i.image} alt="" className="w-12 h-14 object-cover rounded" />
                                  <div className="text-sm">
                                    <p className="font-medium">{i.name}</p>
                                    <p className="text-gray-500">
                                      {money(i.price)} × {i.quantity} · Size {i.size}
                                    </p>
                                  </div>
                                </div>
                              ))}
                              <p className="text-sm text-gray-500">
                                Items {money(o.itemsAmount)}
                                {Number(o.discount) > 0 && ` − discount ${money(o.discount)}${o.couponCode ? ` (${o.couponCode})` : ''}`}
                                {' '}+ shipping {money(o.deliveryFee)}
                                {o.shippingMethod && ` (${o.shippingMethod.toLowerCase()})`}
                              </p>
                              <p className="text-sm text-gray-500 lg:hidden">
                                {o.paymentMethod} · {o.paid ? 'Paid' : 'Unpaid'}
                              </p>
                            </div>
                            <div className="text-sm text-gray-600 leading-6">
                              <p className="font-medium text-gray-800">
                                {o.address.firstName} {o.address.lastName}
                              </p>
                              <p>{o.address.street}</p>
                              <p>
                                {o.address.city}, {o.address.state} {o.address.zipcode}
                              </p>
                              <p>{o.address.country}</p>
                              <p className="mt-1">☎ {o.address.phone}</p>
                              <p>✉ {o.address.email}</p>
                            </div>
                          </div>
                        </td>
                      </tr>
                    )}
                  </Fragment>
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

export default Orders;
