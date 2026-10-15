import { Link } from "react-router-dom";
import { api } from "../../api/client";
import useApi from "../../components/useApi";
import { Card, ErrorText, Loading, PageTitle, StatusBadge } from "../components/ui";
import { STATUSES, formatDate, money } from "../format";

const ordersWith = (status) => `/admin/orders?status=${status}`;
const orderLink = (id) => `/admin/orders?q=${encodeURIComponent(`#${id}`)}`;
const focusRing = 'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black focus-visible:ring-offset-2';
const Arrow = ({ className = '' }) => (
  <span aria-hidden="true" className={`transition group-hover:translate-x-0.5 group-focus-visible:translate-x-0.5 ${className}`}>→</span>
);

// Same look as the shared <Stat>, but the whole card links to the filtered list behind the number.
// `extra` ({ to, label }) adds a second link inside the card (e.g. "3 hidden"), layered above the card-wide link.
const StatLink = ({ to, label, value, hint, extra, title }) => (
  <div className="group relative h-full bg-white border border-gray-200 rounded-lg p-5 transition hover:border-gray-400 hover:shadow-sm focus-within:border-gray-400">
    <div className="flex items-start justify-between gap-2">
      <Link
        to={to}
        title={title}
        className="text-sm text-gray-500 group-hover:text-black after:absolute after:inset-0 after:rounded-lg focus-visible:outline-none focus-visible:after:ring-2 focus-visible:after:ring-black"
      >
        {label}
      </Link>
      <Arrow className="text-gray-300 group-hover:text-black" />
    </div>
    <p className="text-3xl font-medium mt-2">{value}</p>
    {extra ? (
      <Link to={extra.to} className={`relative z-10 inline-block text-xs text-gray-400 mt-1 underline-offset-2 hover:text-black hover:underline rounded ${focusRing}`}>
        {extra.label}
      </Link>
    ) : (
      hint && <p className="text-xs text-gray-400 mt-1">{hint}</p>
    )}
  </div>
);

const Dashboard = () => {
  const stats = useApi(() => api.adminStats(), []);
  const recent = useApi(() => api.adminOrders({ page: 0, size: 5 }), []);
  const analytics = useApi(() => api.adminAnalytics(), []);

  if (stats.loading) return <Loading />;
  if (stats.error) return <ErrorText error={stats.error} />;
  const s = stats.data;
  const pending = s.ordersByStatus.ORDER_PLACED || 0;
  const maxCount = Math.max(1, ...Object.values(s.ordersByStatus));

  return (
    <>
      <PageTitle title="Dashboard" />

      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
        <StatLink to={ordersWith('DELIVERED')} title="View delivered orders" label="Revenue" value={money(s.revenue)} hint="excluding cancelled" />
        <StatLink to="/admin/orders" title="View all orders" label="Orders" value={s.totalOrders} />
        <StatLink to={ordersWith('ORDER_PLACED')} title="View orders waiting to ship" label="To fulfil" value={pending} hint="placed, not shipped yet" />
        <StatLink
          to="/admin/products?visibility=visible"
          title="View visible products"
          label="Products"
          value={s.activeProducts}
          extra={{ to: '/admin/products?visibility=hidden', label: `${s.hiddenProducts} hidden` }}
        />
        <StatLink to="/admin/customers" title="View customers" label="Customers" value={s.customers} />
      </div>

      <div className="grid lg:grid-cols-3 gap-4 mt-6">
        <Card className="p-5 lg:col-span-1">
          <h2 className="font-medium mb-4">Orders by status</h2>
          <div className="flex flex-col gap-1 -mx-2">
            {STATUSES.map(([value, label]) => (
              <Link
                key={value}
                to={ordersWith(value)}
                title={`View ${label.toLowerCase()} orders`}
                className={`group block rounded px-2 py-1.5 hover:bg-gray-50 ${focusRing}`}
              >
                <div className="flex justify-between text-sm mb-1">
                  <span className="group-hover:underline underline-offset-2">{label}</span>
                  <span className="flex items-center gap-1.5 text-gray-500">
                    {s.ordersByStatus[value] || 0}
                    <Arrow className="text-gray-300 opacity-0 group-hover:opacity-100 group-hover:text-black group-focus-visible:opacity-100" />
                  </span>
                </div>
                <div className="h-2 rounded bg-gray-100">
                  <div className="h-2 rounded bg-black" style={{ width: `${((s.ordersByStatus[value] || 0) / maxCount) * 100}%` }} />
                </div>
              </Link>
            ))}
          </div>
        </Card>

        <Card className="p-5 lg:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-medium">Recent orders</h2>
            <Link to="/admin/orders" className={`group inline-flex items-center gap-1 text-sm text-gray-500 hover:text-black rounded ${focusRing}`}>
              View all orders <Arrow />
            </Link>
          </div>
          {recent.loading && <Loading />}
          <ErrorText error={recent.error} />
          {recent.data && recent.data.content.length === 0 && <p className="py-6 text-center text-gray-400">No orders yet</p>}
          <div className="divide-y -mx-2">
            {recent.data?.content.map((o) => (
              <Link
                key={o.id}
                to={orderLink(o.id)}
                title={`Open order #${o.id}`}
                className={`group px-2 py-3 flex items-center justify-between gap-3 text-sm rounded hover:bg-gray-50 ${focusRing}`}
              >
                <div className="min-w-0">
                  <p className="font-medium truncate group-hover:underline underline-offset-2">#{o.id} · {o.address.firstName} {o.address.lastName}</p>
                  <p className="text-gray-400 text-xs">{formatDate(o.createdAt)}</p>
                </div>
                <div className="flex items-center gap-3 shrink-0">
                  <span className="font-medium">{money(o.total)}</span>
                  <StatusBadge status={o.status} />
                  <Arrow className="text-gray-300 group-hover:text-black" />
                </div>
              </Link>
            ))}
          </div>
        </Card>
      </div>

      {analytics.data && <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <Card className="p-5">
          <div className="mb-4 flex justify-between gap-3">
            <h2 className="font-medium">Revenue · last 30 days</h2>
            <Link to="/admin/inventory?level=low" title="View low-stock sizes" className={`group inline-flex items-center gap-1 text-sm text-red-600 hover:underline underline-offset-2 rounded ${focusRing}`}>
              {analytics.data.lowStockCount} low-stock sizes <Arrow />
            </Link>
          </div>
          <div className="flex h-40 items-end gap-1">{analytics.data.revenueByDay.map((d) => { const max = Math.max(1, ...analytics.data.revenueByDay.map((x) => Number(x.revenue))); return <div key={d.day} title={`${d.day}: ${money(d.revenue)}`} className="min-w-1 flex-1 bg-black" style={{ height: `${Math.max(4, Number(d.revenue) / max * 100)}%` }} />; })}</div>
        </Card>
        <Card className="p-5">
          <h2 className="mb-4 font-medium">Top-selling products</h2>
          <div className="divide-y -mx-2">
            {analytics.data.topProducts.map((p, i) => {
              const body = (
                <>
                  <span className="min-w-0 truncate group-hover:underline underline-offset-2">{i + 1}. {p.name}</span>
                  <span className="flex items-center gap-2 shrink-0"><span><b>{p.quantity}</b> sold · {money(p.revenue)}</span>{p.productId != null && <Arrow className="text-gray-300 group-hover:text-black" />}</span>
                </>
              );
              const row = 'flex justify-between gap-3 px-2 py-3 text-sm';
              return p.productId != null ? (
                <Link
                  key={`${p.productId}-${p.name}`}
                  to={`/admin/products?product=${encodeURIComponent(p.productId)}`}
                  title={`Edit ${p.name}`}
                  className={`group ${row} rounded hover:bg-gray-50 ${focusRing}`}
                >
                  {body}
                </Link>
              ) : (
                <div key={`none-${p.name}`} className={row}>{body}</div>
              );
            })}
            {analytics.data.topProducts.length === 0 && <p className="px-2 text-gray-400">No sales yet</p>}
          </div>
        </Card>
      </div>}
    </>
  );
};

export default Dashboard;
