import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import useApi from "../../components/useApi";
import useUnsavedChanges from "../../components/useUnsavedChanges";
import ConfirmDialog from "../../components/ConfirmDialog";
import { DatePicker } from "@/components/ui/date-picker";
import { Card, ClearFilters, ConfirmDelete, Dropdown, Empty, ErrorText, Loading, PageTitle, Pagination, SearchInput, SortTh, Stat, StatusBadge } from "../components/ui";
import { formatDate, money } from "../format";
import { matches, paginate, sortRows, usePage, useUrlFilters, useUrlSearch } from "../table";
import { validate as runSchema, z } from "@/lib/validation";

const PAGE_SIZE = 10;
const URL_DEFAULTS = { q: '', status: '', sort: 'created', dir: 'desc', coupon: '' };
const ORDERS_PAGE_SIZE = 8;

const STATUS_STYLE = {
  ACTIVE: ['Active', 'bg-green-100 text-green-700'],
  SCHEDULED: ['Scheduled', 'bg-blue-100 text-blue-700'],
  EXPIRED: ['Expired', 'bg-gray-200 text-gray-600'],
  USED_UP: ['Used up', 'bg-amber-100 text-amber-700'],
  INACTIVE: ['Inactive', 'bg-gray-100 text-gray-500'],
};

const EMPTY_FORM = {
  code: '',
  description: '',
  discountType: 'PERCENT',
  percentOff: '10',
  amountOff: '',
  maxDiscount: '',
  minSubtotal: '',
  startsAt: '',
  expiresAt: '',
  usageLimit: '',
  perCustomerLimit: '',
  active: true,
};

// DatePicker value ("yyyy-MM-dd", local day) <-> ISO instant. Start = beginning of the day, expiry = end of the day.
const toDateInput = (iso) => {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};
const startOfDay = (value) => (value ? new Date(`${value}T00:00:00`).toISOString() : null);
const endOfDay = (value) => (value ? new Date(`${value}T23:59:59`).toISOString() : null);
const shortDate = (iso) => new Date(iso).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });

const randomCode = () => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return Array.from({ length: 8 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
};

const discountLabel = (c) =>
  c.discountType === 'FIXED'
    ? `${money(c.amountOff)} off`
    : `${c.percentOff}% off${c.maxDiscount != null ? ` (max ${money(c.maxDiscount)})` : ''}`;

const fromCoupon = (c) => ({
  code: c.code,
  description: c.description || '',
  discountType: c.discountType,
  percentOff: c.percentOff != null ? String(c.percentOff) : '10',
  amountOff: c.amountOff != null ? String(c.amountOff) : '',
  maxDiscount: c.maxDiscount != null ? String(c.maxDiscount) : '',
  minSubtotal: Number(c.minSubtotal) > 0 ? String(c.minSubtotal) : '',
  startsAt: toDateInput(c.startsAt),
  expiresAt: toDateInput(c.expiresAt),
  usageLimit: c.usageLimit != null ? String(c.usageLimit) : '',
  perCustomerLimit: c.perCustomerLimit != null ? String(c.perCustomerLimit) : '',
  active: c.active,
});

// Optional numeric input: "" = not set (null); anything else must match `pattern` (whole number or money).
const WHOLE = /^\d+$/;
const MONEY = /^\d+(\.\d{1,2})?$/;
const optionalNumber = (pattern, message) =>
  z
    .string()
    .trim()
    .refine((v) => v === '' || pattern.test(v), message)
    .transform((v) => (v === '' ? null : Number(v)));

// Same rules as the API's CouponRequest, plus the cross-field checks.
const couponSchema = z
  .object({
    code: z
      .string()
      .trim()
      .toUpperCase()
      .min(1, 'Code is required')
      .regex(/^[A-Z0-9_-]{1,30}$/, 'Letters, digits, - and _ only (max 30)'),
    description: z.string().trim().max(200, 'Use 200 characters or fewer'),
    discountType: z.enum(['PERCENT', 'FIXED']),
    percentOff: optionalNumber(WHOLE, 'Whole number from 1 to 90'),
    amountOff: optionalNumber(MONEY, 'Enter an amount like 5.00'),
    maxDiscount: optionalNumber(MONEY, 'Enter an amount like 20.00'),
    minSubtotal: optionalNumber(MONEY, 'Enter an amount like 50.00'),
    startsAt: z.string(),
    expiresAt: z.string(),
    usageLimit: optionalNumber(WHOLE, 'Whole number, at least 1'),
    perCustomerLimit: optionalNumber(WHOLE, 'Whole number, at least 1'),
    active: z.boolean(),
  })
  .superRefine((f, ctx) => {
    const fail = (path, message) => ctx.addIssue({ code: z.ZodIssueCode.custom, path: [path], message });
    if (f.discountType === 'PERCENT') {
      if (f.percentOff == null || f.percentOff < 1 || f.percentOff > 90) fail('percentOff', 'Whole number from 1 to 90');
      if (f.maxDiscount != null && !(f.maxDiscount > 0)) fail('maxDiscount', 'Must be greater than 0');
    } else {
      if (f.amountOff == null || !(f.amountOff > 0)) fail('amountOff', 'Must be greater than 0');
      else if (f.minSubtotal > 0 && f.amountOff > f.minSubtotal) fail('amountOff', 'Should not be more than the minimum subtotal');
    }
    if (f.usageLimit != null && f.usageLimit < 1) fail('usageLimit', 'Whole number, at least 1');
    if (f.perCustomerLimit != null && f.perCustomerLimit < 1) fail('perCustomerLimit', 'Whole number, at least 1');
    if (f.usageLimit != null && f.perCustomerLimit != null && f.perCustomerLimit > f.usageLimit) {
      fail('perCustomerLimit', 'Cannot exceed the total limit');
    }
    if (f.startsAt && f.expiresAt && f.expiresAt < f.startsAt) fail('expiresAt', 'Must be on or after the start date');
  });

// Returns { errors, body } — errors keyed by field, body ready for the API (null when invalid).
const validate = (f) => {
  const { data, errors } = runSchema(couponSchema, f);
  if (!data) return { errors, body: null };
  const percent = data.discountType === 'PERCENT';
  const body = {
    code: data.code,
    description: data.description || null,
    discountType: data.discountType,
    percentOff: percent ? data.percentOff : null,
    amountOff: percent ? null : data.amountOff,
    maxDiscount: percent ? data.maxDiscount : null,
    minSubtotal: data.minSubtotal ?? 0,
    startsAt: startOfDay(data.startsAt),
    expiresAt: endOfDay(data.expiresAt),
    usageLimit: data.usageLimit,
    perCustomerLimit: data.perCustomerLimit,
    active: data.active,
  };
  return { errors, body };
};

// `as="div"` for Radix-based controls (date picker), which must not sit inside a <label>: clicking it would toggle them.
const Field = ({ label, hint, error, children, className = '', as: Tag = 'label' }) => (
  <Tag className={`flex flex-col gap-1 text-sm ${className}`}>
    <span className="text-gray-600">{label}</span>
    {children}
    {error ? <span className="text-xs text-red-600">{error}</span> : hint && <span className="text-xs text-gray-400">{hint}</span>}
  </Tag>
);

const statusStyle = (status) => STATUS_STYLE[status] || [status, 'bg-gray-100 text-gray-600'];

const CouponStatus = ({ status }) => {
  const [label, color] = statusStyle(status);
  return <span className={`inline-block px-2.5 py-1 rounded-full text-xs font-medium whitespace-nowrap ${color}`}>{label}</span>;
};

const Detail = ({ label, children }) => (
  <div>
    <dt className="text-xs text-gray-500">{label}</dt>
    <dd className="mt-0.5">{children}</dd>
  </div>
);

const Muted = ({ children }) => <span className="text-gray-400">{children}</span>;

// Slide-over with every field of one coupon and the orders that used it.
const CouponPanel = ({ coupon, onClose, onEdit }) => {
  const [page, setPage] = useState(0);
  const { data, loading, error } = useApi(
    () => api.adminOrders({ coupon: coupon.code, page, size: ORDERS_PAGE_SIZE, sort: 'newest' }),
    [coupon.code, coupon.timesUsed, page],
  );
  const orders = data?.content || [];

  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && onClose();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  const percent = coupon.discountType !== 'FIXED';

  return (
    <>
      <div className="fixed inset-0 z-40 bg-black/30" onClick={onClose} />
      <aside
        role="dialog"
        aria-modal="true"
        aria-label={`Coupon ${coupon.code} details`}
        className="fixed top-0 right-0 z-50 h-full w-full sm:w-[30rem] bg-white shadow-xl flex flex-col"
      >
        <div className="flex items-start justify-between gap-3 p-5 border-b">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-lg font-mono font-medium break-all">{coupon.code}</h2>
              <CouponStatus status={coupon.status} />
            </div>
            <p className="text-sm text-gray-500 mt-1">{coupon.description || <Muted>No description</Muted>}</p>
          </div>
          <div className="flex items-center gap-3 shrink-0">
            <button onClick={() => onEdit(coupon)} className="border border-gray-300 rounded px-3 py-1.5 text-sm hover:bg-gray-100">
              Edit
            </button>
            <button onClick={onClose} aria-label="Close" className="text-2xl leading-none text-gray-400 hover:text-black">
              ×
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto">
          <div className="grid grid-cols-2 gap-3 p-5 border-b text-center">
            <div>
              <p className="text-xs text-gray-500">Times used</p>
              <p className="text-lg font-medium">
                {coupon.timesUsed}
                {coupon.usageLimit != null && <span className="text-sm text-gray-400"> / {coupon.usageLimit}</span>}
              </p>
            </div>
            <div>
              <p className="text-xs text-gray-500">Discount given</p>
              <p className="text-lg font-medium">{money(coupon.totalDiscount)}</p>
            </div>
            <p className="col-span-2 text-xs text-gray-400">Counts non-cancelled orders</p>
          </div>

          <dl className="grid grid-cols-2 gap-x-4 gap-y-4 p-5 border-b text-sm">
            <Detail label="Discount type">{percent ? 'Percent' : 'Fixed amount'}</Detail>
            <Detail label="Discount">{percent ? `${coupon.percentOff}% off` : `${money(coupon.amountOff)} off`}</Detail>
            {percent && (
              <Detail label="Max discount">{coupon.maxDiscount != null ? money(coupon.maxDiscount) : <Muted>No cap</Muted>}</Detail>
            )}
            <Detail label="Minimum subtotal">{Number(coupon.minSubtotal) > 0 ? money(coupon.minSubtotal) : <Muted>No minimum</Muted>}</Detail>
            <Detail label="Starts">{coupon.startsAt ? shortDate(coupon.startsAt) : <Muted>Immediately</Muted>}</Detail>
            <Detail label="Expires">{coupon.expiresAt ? `End of ${shortDate(coupon.expiresAt)}` : <Muted>Never</Muted>}</Detail>
            <Detail label="Total uses">{coupon.usageLimit != null ? coupon.usageLimit : <Muted>Unlimited</Muted>}</Detail>
            <Detail label="Uses per customer">{coupon.perCustomerLimit != null ? coupon.perCustomerLimit : <Muted>Unlimited</Muted>}</Detail>
            <Detail label="Enabled">{coupon.active ? 'Yes' : 'No'}</Detail>
            <Detail label="Created">{coupon.createdAt ? formatDate(coupon.createdAt) : <Muted>—</Muted>}</Detail>
          </dl>

          <div className="p-5">
            <div className="flex items-center justify-between mb-3">
              <h3 className="font-medium">Orders using this coupon</h3>
              {data && (
                <span className="text-xs text-gray-500">
                  {data.totalElements} order{data.totalElements === 1 ? '' : 's'}
                  {data.totalElements > coupon.timesUsed && ` · ${data.totalElements - coupon.timesUsed} cancelled, not counted`}
                </span>
              )}
            </div>
            {loading && <Loading />}
            <ErrorText error={error} />
            {!loading && !error && orders.length === 0 && <Empty>No orders have used this coupon yet</Empty>}
            <ul className="flex flex-col gap-3">
              {orders.map((o) => {
                // Cancelled orders are listed for reference but do not count towards "Times used" or the discount total.
                const counted = o.status !== 'CANCELLED';
                return (
                <li key={o.id} className={`border rounded-lg p-3 ${counted ? '' : 'bg-gray-50 opacity-70'}`}>
                  <div className="flex items-center justify-between gap-2">
                    <Link to={`/admin/orders?q=${encodeURIComponent(`#${o.id}`)}`} className="font-medium hover:underline">
                      Order #{o.id}
                    </Link>
                    <StatusBadge status={o.status} />
                  </div>
                  <p className="text-xs text-gray-400 mt-1">{formatDate(o.createdAt)}</p>
                  <div className="flex items-end justify-between gap-3 mt-2">
                    <div className="min-w-0 text-sm">
                      <p className="truncate">{[o.address?.firstName, o.address?.lastName].filter(Boolean).join(' ') || <Muted>Unknown</Muted>}</p>
                      <p className="text-xs text-gray-500 truncate">{o.address?.email}</p>
                    </div>
                    <div className="text-right shrink-0">
                      <p className="font-medium">{money(o.total)}</p>
                      <p className={`text-xs ${counted ? 'text-green-700' : 'text-gray-400 line-through'}`}>−{money(o.discount)}</p>
                      {!counted && <p className="text-[11px] text-gray-400">not counted</p>}
                    </div>
                  </div>
                </li>
                );
              })}
            </ul>
            <Pagination page={page} totalPages={data?.totalPages || 0} total={data?.totalElements} pageSize={data?.size} onChange={setPage} />
          </div>
        </div>
      </aside>
    </>
  );
};

const inputClass = (error) => `border rounded px-3 py-2 bg-white ${error ? 'border-red-400' : 'border-gray-300'}`;

const CouponForm = ({ editing, onSaved, onCancel, onDirtyChange }) => {
  const [initial] = useState(() => (editing ? fromCoupon(editing) : EMPTY_FORM));
  const [form, setForm] = useState(initial);
  const dirty = JSON.stringify(form) !== JSON.stringify(initial);
  useEffect(() => onDirtyChange(dirty), [dirty, onDirtyChange]);
  const [errors, setErrors] = useState({});
  const [saving, setSaving] = useState(false);
  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.type === 'checkbox' ? e.target.checked : e.target.value }));

  const submit = async (e) => {
    e.preventDefault();
    const { errors: found, body } = validate(form);
    setErrors(found);
    if (Object.keys(found).length) return;
    setSaving(true);
    try {
      const saved = editing ? await api.adminUpdateCoupon(editing.id, body) : await api.adminAddCoupon(body);
      toast.success(editing ? `Coupon ${saved.code} updated` : `Coupon ${saved.code} created`);
      onSaved();
    } catch (err) {
      if (err.fieldErrors) setErrors(err.fieldErrors);
      toast.error(err.message);
    } finally {
      setSaving(false);
    }
  };

  const percent = form.discountType === 'PERCENT';

  return (
    <Card className="p-5 mb-6">
      <form onSubmit={submit} noValidate>
        <div className="flex items-center justify-between mb-4">
          <h2 className="font-medium">{editing ? `Edit coupon ${editing.code}` : 'New coupon'}</h2>
          <button type="button" onClick={onCancel} className="text-sm text-gray-500 hover:text-black">
            Cancel
          </button>
        </div>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Field label="Code" error={errors.code} hint="Customers type this at checkout">
            <div className="flex gap-2">
              <input
                value={form.code}
                onChange={(e) => setForm((f) => ({ ...f, code: e.target.value.toUpperCase() }))}
                maxLength={30}
                placeholder="SUMMER10"
                className={`${inputClass(errors.code)} flex-1 min-w-0 uppercase`}
              />
              <button
                type="button"
                onClick={() => setForm((f) => ({ ...f, code: randomCode() }))}
                className="border border-gray-300 rounded px-2 text-xs text-gray-600 hover:bg-gray-100"
              >
                Generate
              </button>
            </div>
          </Field>

          <Field label="Description (optional)" error={errors.description} className="lg:col-span-3">
            <input
              value={form.description}
              onChange={set('description')}
              maxLength={200}
              placeholder="e.g. Summer sale for newsletter subscribers"
              className={inputClass(errors.description)}
            />
          </Field>

          <Field label="Discount type">
            <div className="inline-flex rounded border border-gray-300 overflow-hidden">
              {[
                ['PERCENT', 'Percent %'],
                ['FIXED', 'Fixed $'],
              ].map(([value, label]) => (
                <button
                  key={value}
                  type="button"
                  onClick={() => setForm((f) => ({ ...f, discountType: value }))}
                  className={`flex-1 px-3 py-2 ${form.discountType === value ? 'bg-black text-white' : 'bg-white text-gray-600 hover:bg-gray-100'}`}
                >
                  {label}
                </button>
              ))}
            </div>
          </Field>

          {percent ? (
            <>
              <Field label="Percent off" error={errors.percentOff} hint="1–90%">
                <input type="text" inputMode="numeric" value={form.percentOff} onChange={set('percentOff')} className={inputClass(errors.percentOff)} />
              </Field>
              <Field label="Max discount ($)" error={errors.maxDiscount} hint="Optional cap per order">
                <input type="text" inputMode="decimal" value={form.maxDiscount} onChange={set('maxDiscount')} placeholder="No cap" className={inputClass(errors.maxDiscount)} />
              </Field>
            </>
          ) : (
            <Field label="Amount off ($)" error={errors.amountOff} className="lg:col-span-2">
              <input type="text" inputMode="decimal" value={form.amountOff} onChange={set('amountOff')} placeholder="5.00" className={inputClass(errors.amountOff)} />
            </Field>
          )}

          <Field label="Minimum subtotal ($)" error={errors.minSubtotal} hint="Items total before shipping">
            <input type="text" inputMode="decimal" value={form.minSubtotal} onChange={set('minSubtotal')} placeholder="No minimum" className={inputClass(errors.minSubtotal)} />
          </Field>

          <Field as="div" label="Starts on" hint="Leave empty to start now">
            <DatePicker
              value={form.startsAt}
              onChange={(v) => setForm((f) => ({ ...f, startsAt: v }))}
              placeholder="Now"
              className="w-full [&>button]:border-gray-300 [&>button]:rounded"
            />
          </Field>
          <Field as="div" label="Expires after" error={errors.expiresAt} hint="Valid through the end of this day">
            <DatePicker
              value={form.expiresAt}
              onChange={(v) => setForm((f) => ({ ...f, expiresAt: v }))}
              min={form.startsAt || undefined}
              placeholder="Never"
              className={`w-full [&>button]:rounded ${errors.expiresAt ? '[&>button]:border-red-400' : '[&>button]:border-gray-300'}`}
            />
          </Field>
          <Field label="Total uses" error={errors.usageLimit} hint="Leave empty for unlimited">
            <input type="text" inputMode="numeric" value={form.usageLimit} onChange={set('usageLimit')} placeholder="Unlimited" className={inputClass(errors.usageLimit)} />
          </Field>
          <Field label="Uses per customer" error={errors.perCustomerLimit} hint="Leave empty for unlimited">
            <input type="text" inputMode="numeric" value={form.perCustomerLimit} onChange={set('perCustomerLimit')} placeholder="Unlimited" className={inputClass(errors.perCustomerLimit)} />
          </Field>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 mt-5 pt-4 border-t">
          <p className="text-xs text-gray-400">Turn coupons on or off with the switch in the list.</p>
          <button disabled={saving} className="bg-black text-white text-sm px-5 py-2 rounded disabled:opacity-50">
            {saving ? 'Saving...' : editing ? 'Save changes' : 'Create coupon'}
          </button>
        </div>
      </form>
    </Card>
  );
};

const Coupons = () => {
  const [version, setVersion] = useState(0);
  const { data, loading, error } = useApi(() => api.adminCoupons(), [version]);
  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState(null);
  // Search, status, sort and the open coupon (`?coupon=<id>`) live in the URL, so a refresh or shared link keeps them.
  const [filters, setFilters] = useUrlFilters(URL_DEFAULTS);
  const [searchText, setSearchText] = useUrlSearch(filters, setFilters, 'q');
  const search = filters.q; // debounced: the URL updates 300 ms after typing stops
  const status = filters.status;
  const sort = useMemo(() => ({ key: filters.sort, dir: filters.dir === 'asc' ? 'asc' : 'desc' }), [filters.sort, filters.dir]);
  const onSort = (key) =>
    setFilters(sort.key === key ? { sort: key, dir: sort.dir === 'asc' ? 'desc' : 'asc' } : { sort: key, dir: key === 'code' ? 'asc' : 'desc' });
  const reload = () => setVersion((v) => v + 1);

  const coupons = useMemo(() => data || [], [data]);
  // Looked up from the list (not stored), so the drawer shows fresh numbers after a reload.
  const viewing = filters.coupon ? coupons.find((c) => String(c.id) === filters.coupon) : null;
  const openView = (c) => setFilters({ coupon: c.id });
  const closeView = () => setFilters({ coupon: '' });

  const visible = useMemo(() => {
    const filtered = coupons.filter((c) => (!status || c.status === status) && matches(search, c.code, c.description));
    return sortRows(filtered, sort, {
      code: (c) => c.code,
      used: (c) => c.timesUsed,
      given: (c) => Number(c.totalDiscount),
      expires: (c) => (c.expiresAt ? new Date(c.expiresAt).getTime() : null),
      created: (c) => c.id,
    });
  }, [coupons, search, status, sort]);
  const [page, setPage] = usePage(JSON.stringify([search, status, sort]));
  const paged = paginate(visible, page, PAGE_SIZE);

  const stats = useMemo(
    () => ({
      active: coupons.filter((c) => c.status === 'ACTIVE').length,
      uses: coupons.reduce((sum, c) => sum + c.timesUsed, 0),
      given: coupons.reduce((sum, c) => sum + Number(c.totalDiscount), 0),
    }),
    [coupons],
  );

  // Unsaved coupon form: closing it, switching to another coupon or leaving the page asks first.
  const [formDirty, setFormDirty] = useState(false);
  const [pending, setPending] = useState(null); // action waiting for "discard changes?"
  const { dialog: leaveDialog } = useUnsavedChanges(formOpen && formDirty);
  const guard = (action) => (formOpen && formDirty ? setPending(() => action) : action());

  const openNew = () => {
    setEditing(null);
    setFormOpen(true);
  };
  const openEdit = (c) => guard(() => {
    if (filters.coupon) closeView();
    setEditing(c);
    setFormOpen(true);
    setFormDirty(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });
  const closeForm = () => {
    setFormOpen(false);
    setEditing(null);
    setFormDirty(false);
  };

  const toggleActive = async (c) => {
    try {
      await api.adminSetCouponActive(c.id, !c.active);
      toast.success(`${c.code} ${c.active ? 'deactivated' : 'activated'}`);
      reload();
    } catch (e) {
      toast.error(e.message);
    }
  };

  const remove = async (c) => {
    try {
      await api.adminDeleteCoupon(c.id);
      toast.success(`Coupon ${c.code} deleted`);
      if (editing?.id === c.id) closeForm();
      if (filters.coupon === String(c.id)) closeView();
      reload();
    } catch (e) {
      toast.error(e.message);
    }
  };

  const copy = (code) => {
    navigator.clipboard?.writeText(code).then(
      () => toast.success(`Copied ${code}`),
      () => {},
    );
  };

  return (
    <>
      <PageTitle title="Coupons">
        {!formOpen && (
          <button onClick={openNew} className="bg-black text-white text-sm px-4 py-2 rounded">
            + New coupon
          </button>
        )}
      </PageTitle>

      {formOpen && (
        <CouponForm
          key={editing?.id ?? 'new'}
          editing={editing}
          onCancel={() => guard(closeForm)}
          onDirtyChange={setFormDirty}
          onSaved={() => {
            closeForm();
            reload();
          }}
        />
      )}

      {loading && !data && <Loading />}
      <ErrorText error={error} />

      {data && (
        <>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <Stat label="Coupons" value={coupons.length} />
            <Stat label="Active now" value={stats.active} />
            <Stat label="Times used" value={stats.uses} hint="non-cancelled orders" />
            <Stat label="Discount given" value={money(stats.given)} />
          </div>

          <div className="flex flex-wrap items-center gap-3 mb-4">
            <SearchInput value={searchText} onChange={setSearchText} placeholder="Search code or description" />
            <Dropdown
              value={status}
              onChange={(v) => setFilters({ status: v })}
              options={[['', 'All statuses'], ...Object.entries(STATUS_STYLE).map(([value, [label]]) => [value, label])]}
              placeholder="All statuses"
              aria-label="Filter by status"
              className="w-44"
            />
            <span className="text-sm text-gray-500">{visible.length} coupons</span>
            {(searchText || status) && (
              <ClearFilters
                count={[searchText, status].filter(Boolean).length}
                onClick={() => {
                  setSearchText('');
                  setFilters({ q: '', status: '' });
                }}
              />
            )}
          </div>

          <Card className="overflow-x-auto">
            {visible.length === 0 ? (
              <Empty>{coupons.length === 0 ? 'No coupons yet — create your first one' : 'No coupons match these filters'}</Empty>
            ) : (
              <table className="w-full text-sm">
                <thead className="bg-gray-50 text-gray-500 text-left">
                  <tr>
                    <SortTh label="Code" sortKey="code" sort={sort} onSort={onSort} />
                    <th className="px-4 py-3 font-normal">Discount</th>
                    <th className="px-4 py-3 font-normal hidden lg:table-cell">Conditions</th>
                    <SortTh label="Times used" sortKey="used" sort={sort} onSort={onSort} />
                    <SortTh label="Total discount" sortKey="given" sort={sort} onSort={onSort} className="hidden md:table-cell" />
                    <SortTh label="Expires" sortKey="expires" sort={sort} onSort={onSort} className="hidden md:table-cell" />
                    <th className="px-4 py-3 font-normal" title="Whether customers can use this coupon right now">Status</th>
                    <th className="px-4 py-3 font-normal text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {paged.rows.map((c) => {
                    const conditions = [
                      Number(c.minSubtotal) > 0 && `Min. ${money(c.minSubtotal)}`,
                      c.perCustomerLimit && `${c.perCustomerLimit}× per customer`,
                      c.startsAt && `From ${shortDate(c.startsAt)}`,
                    ].filter(Boolean);
                    return (
                      <tr
                        key={c.id}
                        // Clicking the row opens the details; its own buttons and links keep their action.
                        onClick={(e) => !e.target.closest('button, a, input') && openView(c)}
                        className={`cursor-pointer hover:bg-gray-50 ${c.status === 'ACTIVE' ? '' : 'bg-gray-50/60'}`}
                      >
                        <td className="px-4 py-3">
                          <button onClick={() => copy(c.code)} title="Copy code" className="font-mono font-medium hover:underline">
                            {c.code}
                          </button>
                          {c.description && <p className="text-xs text-gray-400 max-w-[14rem] truncate">{c.description}</p>}
                        </td>
                        <td className="px-4 py-3 whitespace-nowrap">{discountLabel(c)}</td>
                        <td className="px-4 py-3 hidden lg:table-cell text-xs text-gray-500">
                          {conditions.length ? conditions.join(' · ') : 'None'}
                        </td>
                        <td className="px-4 py-3 whitespace-nowrap">
                          {c.timesUsed > 0 ? (
                            <Link to={`/admin/orders?coupon=${encodeURIComponent(c.code)}`} title="See the orders that used this coupon"
                              className="font-medium underline underline-offset-2 hover:text-gray-600">
                              {c.timesUsed}
                            </Link>
                          ) : c.timesUsed}
                          {c.usageLimit != null && <span className="text-gray-400"> / {c.usageLimit}</span>}
                          {c.usageLimit != null && (
                            <div className="mt-1 h-1 w-16 rounded bg-gray-200">
                              <div className="h-1 rounded bg-black" style={{ width: `${Math.min(100, (c.timesUsed / c.usageLimit) * 100)}%` }} />
                            </div>
                          )}
                        </td>
                        <td className="px-4 py-3 hidden md:table-cell">{money(c.totalDiscount)}</td>
                        <td className="px-4 py-3 hidden md:table-cell whitespace-nowrap">
                          {c.expiresAt ? shortDate(c.expiresAt) : <span className="text-gray-400">Never</span>}
                        </td>
                        <td className="px-4 py-3">
                          <CouponStatus status={c.status} />
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center justify-end gap-3 whitespace-nowrap">
                            <button
                              onClick={() => toggleActive(c)}
                              role="switch"
                              aria-checked={c.active}
                              aria-label={`${c.active ? 'Deactivate' : 'Activate'} ${c.code}`}
                              className={`relative w-10 h-6 rounded-full transition-colors shrink-0 ${c.active ? 'bg-black' : 'bg-gray-300'}`}
                            >
                              <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white transition-transform ${c.active ? 'translate-x-4' : ''}`} />
                            </button>
                            <button onClick={() => openView(c)} className="text-sm text-gray-700 hover:underline">
                              View
                            </button>
                            <button onClick={() => openEdit(c)} className="text-sm text-gray-700 hover:underline">
                              Edit
                            </button>
                            <ConfirmDelete onConfirm={() => remove(c)} />
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </Card>
          <p className="mt-2 text-xs text-gray-400">
            <b className="font-medium text-gray-500">Times used</b>: orders that used the coupon (cancelled orders don&apos;t count) ·{' '}
            <b className="font-medium text-gray-500">Total discount</b>: money customers saved with it ·{' '}
            <b className="font-medium text-gray-500">Status</b>: Active = usable now, Scheduled = not started yet, Expired = past its end date,
            Used up = usage limit reached, Inactive = switched off.
          </p>
          <Pagination page={paged.page} totalPages={paged.totalPages} total={paged.total} pageSize={paged.pageSize} onChange={setPage} />
        </>
      )}
      {viewing && <CouponPanel key={viewing.id} coupon={viewing} onClose={closeView} onEdit={openEdit} />}
      {leaveDialog}
      {pending && (
        <ConfirmDialog
          message="This coupon has unsaved changes. Discard them?"
          onCancel={() => setPending(null)}
          onConfirm={() => { const action = pending; setPending(null); action(); }}
        />
      )}
    </>
  );
};

export default Coupons;
