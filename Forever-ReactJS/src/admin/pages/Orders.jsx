import { Fragment, useEffect, useState } from "react";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import useApi from "../../components/useApi";
import { Card, ClearFilters, Dropdown, Empty, ErrorText, Loading, PageTitle, Pagination, SearchInput, SortTh, StatusBadge } from "../components/ui";
import { STATUSES, formatDate, money } from "../format";
import { DatePicker } from "@/components/ui/date-picker";
import { usePage, useUrlFilters, useUrlSearch } from "../table";
import { validate, z } from "@/lib/validation";

const PAGE_SIZE = 10;
const PAYMENT_METHODS = [
  ['COD', 'Cash on delivery'],
  ['PAYWAY', 'ABA PayWay'],
];
const paymentLabel = (value) => PAYMENT_METHODS.find(([v]) => v === value)?.[1] || value;
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

// URL query params for the filters; `coupon=CODE` comes from the Coupons page. `sort` is "<column>_<dir>".
const FILTER_DEFAULTS = { q: '', status: '', paymentMethod: '', from: '', to: '', coupon: '', sort: 'date_desc' };
const parseSort = (value) => {
  const [key, dir] = value.split('_');
  return ['date', 'total', 'status'].includes(key) && ['asc', 'desc'].includes(dir) ? { key, dir } : { key: 'date', dir: 'desc' };
};

const Orders = () => {
  const [filters, setFilters] = useUrlFilters(FILTER_DEFAULTS);
  const { q, status, paymentMethod, from, to, coupon } = filters;
  const [search, setSearch] = useUrlSearch(filters, setFilters);
  const sort = parseSort(filters.sort);
  const onSort = (key) =>
    setFilters({ sort: `${key}_${sort.key === key ? (sort.dir === 'asc' ? 'desc' : 'asc') : key === 'status' ? 'asc' : 'desc'}` });
  const [page, setPage] = usePage(JSON.stringify([q, status, paymentMethod, from, to, coupon, filters.sort]));
  const [version, setVersion] = useState(0);
  const [openId, setOpenId] = useState(null);
  const [updating, setUpdating] = useState(null);

  const { data, loading, error } = useApi(
    () =>
      api.adminOrders({
        q: q || undefined,
        status: status || undefined,
        paymentMethod: paymentMethod || undefined,
        from: from || undefined,
        to: to || undefined,
        coupon: coupon || undefined,
        sort: toApiSort(sort),
        page,
        size: PAGE_SIZE,
      }),
    [q, status, paymentMethod, from, to, coupon, filters.sort, page, version],
  );

  const [cancelling, setCancelling] = useState(null); // order waiting for a cancel reason

  // Returns true when saved. Cancelling first asks for a reason (see CancelOrderDialog).
  const changeStatus = async (order, next, reason) => {
    if (next === order.status) return false;
    if (next === 'CANCELLED' && reason === undefined) {
      setCancelling(order);
      return false;
    }
    setUpdating(order.id);
    try {
      await api.adminUpdateOrderStatus(order.id, next, reason);
      toast.success(
        next === 'CANCELLED'
          ? `Order #${order.id} cancelled. ${order.address.email} has been emailed the reason.`
          : `Order #${order.id} is now "${statusLabel(next)}"`,
      );
      setVersion((v) => v + 1);
      return true;
    } catch (e) {
      toast.error(e.message);
      return false;
    } finally {
      setUpdating(null);
    }
  };

  const orders = data?.content || [];
  const filtered = search || status || paymentMethod || from || to || coupon;
  const clearFilters = () => {
    setSearch('');
    setFilters({ q: '', status: '', paymentMethod: '', from: '', to: '', coupon: '' });
  };

  return (
    <>
      <PageTitle title="Orders">
        {data && <span className="text-sm text-gray-500">{data.totalElements} orders</span>}
      </PageTitle>

      {coupon && (
        <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-black bg-gray-50 px-3 py-1 text-sm">
          Orders using coupon <b className="font-mono">{coupon}</b>
          <button type="button" onClick={() => setFilters({ coupon: '' })} aria-label="Remove coupon filter" className="text-gray-500 hover:text-black">×</button>
        </div>
      )}

      <div className="flex flex-wrap gap-2 mb-3">
        {[['', 'All'], ...STATUSES.map(([v, l]) => [v, l])].map(([value, label]) => (
          <button
            key={value}
            onClick={() => setFilters({ status: value })}
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
        <Dropdown
          value={paymentMethod}
          onChange={(v) => setFilters({ paymentMethod: v })}
          aria-label="Payment method"
          options={[['', 'All payment methods'], ...PAYMENT_METHODS]}
          className="w-auto min-w-[11rem] h-[38px]"
        />
        <div className="flex flex-col gap-1 text-xs text-gray-500">
          From
          <DatePicker value={from} max={to || undefined} onChange={(v) => setFilters({ from: v })} placeholder="Any date" className="w-40" />
        </div>
        <div className="flex flex-col gap-1 text-xs text-gray-500">
          To
          <DatePicker value={to} min={from || undefined} onChange={(v) => setFilters({ to: v })} placeholder="Any date" className="w-40" />
        </div>
        {filtered && (
          <div className="pb-0.5">
            <ClearFilters onClick={clearFilters} count={[search, status, paymentMethod, from, to, coupon].filter(Boolean).length} />
          </div>
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
                      <td className="px-4 py-3 hidden lg:table-cell">{paymentLabel(o.paymentMethod)}</td>
                      <td className="px-4 py-3 font-medium">
                        {money(o.total)}
                        {o.couponCode && <p className="text-xs font-normal text-gray-400">{o.couponCode}</p>}
                      </td>
                      <td className="px-4 py-3" onClick={(e) => e.stopPropagation()}>
                        {options.length === 0 ? (
                          <>
                            <StatusBadge status={o.status} />
                            {o.status === 'CANCELLED' && o.cancelledBy && (
                              <p className="mt-1 text-xs text-gray-400">by {o.cancelledBy === 'ADMIN' ? 'store' : 'customer'}</p>
                            )}
                          </>
                        ) : (
                          <Dropdown
                            value={o.status}
                            disabled={updating === o.id}
                            onChange={(v) => changeStatus(o, v)}
                            aria-label={`Status of order ${o.id}`}
                            options={[[o.status, statusLabel(o.status)], ...options.map((v) => [v, `→ ${statusLabel(v)}`])]}
                            className="w-auto min-w-[10rem] h-8"
                          />
                        )}
                      </td>
                    </tr>
                    {openId === o.id && (
                      <tr className="bg-gray-50">
                        <td colSpan={5} className="px-4 py-4">
                          {o.status === 'CANCELLED' && (
                            <p className="mb-4 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800">
                              Cancelled by {o.cancelledBy === 'ADMIN' ? 'the store' : o.cancelledBy === 'CUSTOMER' ? 'the customer' : 'unknown'}
                              {o.cancelReason ? <>: <span className="font-medium">{o.cancelReason}</span></> : ' (no reason given)'}
                            </p>
                          )}
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
                              <p className="text-sm text-gray-500 lg:hidden">{paymentLabel(o.paymentMethod)}</p>
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

      <Pagination page={page} totalPages={data?.totalPages || 0} total={data?.totalElements} pageSize={data?.size} onChange={setPage} />

      {cancelling && (
        <CancelOrderDialog
          order={cancelling}
          onCancel={() => setCancelling(null)}
          onConfirm={async (reason) => {
            if (await changeStatus(cancelling, 'CANCELLED', reason)) setCancelling(null);
          }}
        />
      )}
    </>
  );
};

const REASON_MAX = 500;
const QUICK_REASONS = [
  'An item in your order is out of stock',
  'We could not reach you to confirm the delivery',
  'The delivery address is outside our delivery area',
  'Cancelled at your request',
];
const reasonSchema = z
  .string()
  .trim()
  .min(5, 'Tell the customer why (at least 5 characters)')
  .max(REASON_MAX, `Use ${REASON_MAX} characters or fewer`);

// Asks why the order is cancelled; the reason is emailed to the customer and shown on their order.
const CancelOrderDialog = ({ order, onCancel, onConfirm }) => {
  const [reason, setReason] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [busy, setBusy] = useState(false);
  const error = submitted ? validate(reasonSchema, reason).errors._form : null;

  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && !busy && onCancel();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [busy, onCancel]);

  const submit = async (e) => {
    e.preventDefault();
    setSubmitted(true);
    const { data } = validate(reasonSchema, reason);
    if (!data) return;
    setBusy(true);
    try {
      await onConfirm(data);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-[1100] flex items-center justify-center bg-black/50 px-4"
      onMouseDown={(e) => e.target === e.currentTarget && !busy && onCancel()}
    >
      <form
        onSubmit={submit}
        noValidate
        role="dialog"
        aria-modal="true"
        aria-labelledby="cancel-order-title"
        className="w-full max-w-lg rounded-lg bg-white p-6 shadow-2xl"
      >
        <h2 id="cancel-order-title" className="text-lg font-semibold text-gray-900">Cancel order #{order.id}?</h2>
        <p className="mt-2 text-sm leading-6 text-gray-600">
          The stock is put back and {order.address.firstName} ({order.address.email}) gets an email with your reason.
        </p>

        <p className="mt-4 mb-1.5 text-xs text-gray-500">Quick reasons</p>
        <div className="flex flex-wrap gap-2">
          {QUICK_REASONS.map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => setReason(r)}
              className={`rounded-full border px-3 py-1 text-xs ${reason === r ? 'border-black bg-black text-white' : 'border-gray-300 text-gray-600 hover:bg-gray-100'}`}
            >
              {r}
            </button>
          ))}
        </div>

        <label htmlFor="cancel-reason" className="mt-4 block text-sm text-gray-600 mb-1.5">
          Reason for the customer
        </label>
        <textarea
          id="cancel-reason"
          autoFocus
          rows={4}
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          maxLength={REASON_MAX}
          aria-invalid={Boolean(error)}
          aria-describedby="cancel-reason-help"
          placeholder="e.g. The jacket in size M sold out before we could pack your order."
          className={`w-full rounded border px-3 py-2 text-sm focus:outline-none ${error ? 'border-red-400' : 'border-gray-300 focus:border-black'}`}
        />
        <div id="cancel-reason-help" className="mt-1 flex justify-between text-xs">
          <span className="text-red-600">{error}</span>
          <span className="text-gray-400">{reason.length}/{REASON_MAX}</span>
        </div>

        <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <button type="button" onClick={onCancel} disabled={busy}
            className="rounded border border-gray-300 px-5 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">
            Keep order
          </button>
          <button type="submit" disabled={busy}
            className="rounded bg-red-600 px-5 py-2.5 text-sm font-medium text-white hover:bg-red-700 disabled:opacity-50">
            {busy ? 'Cancelling...' : 'Cancel order and email customer'}
          </button>
        </div>
      </form>
    </div>
  );
};

export default Orders;
