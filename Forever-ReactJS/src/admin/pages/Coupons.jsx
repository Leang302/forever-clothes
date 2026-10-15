import { useMemo, useState } from "react";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import useApi from "../../components/useApi";
import { Card, ConfirmDelete, Empty, ErrorText, Loading, PageTitle, SearchInput, SortTh, Stat } from "../components/ui";
import { money } from "../format";
import { matches, sortRows, useSort } from "../table";

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

// <input type="date"> value (local day) <-> ISO instant. Start = beginning of the day, expiry = end of the day.
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

// Returns { errors, body } — errors keyed by field, body ready for the API.
const validate = (f) => {
  const errors = {};
  const num = (v) => (v === '' ? null : Number(v));
  const code = f.code.trim().toUpperCase();
  if (!code) errors.code = 'Code is required';
  else if (!/^[A-Z0-9_-]{1,30}$/.test(code)) errors.code = 'Letters, digits, - and _ only (max 30)';

  const percent = num(f.percentOff);
  const amount = num(f.amountOff);
  const max = num(f.maxDiscount);
  const min = num(f.minSubtotal);
  const usage = num(f.usageLimit);
  const perCustomer = num(f.perCustomerLimit);

  if (f.discountType === 'PERCENT') {
    if (percent == null || !Number.isInteger(percent) || percent < 1 || percent > 90) errors.percentOff = 'Whole number from 1 to 90';
    if (max != null && !(max > 0)) errors.maxDiscount = 'Must be greater than 0';
  } else if (amount == null || !(amount > 0)) {
    errors.amountOff = 'Must be greater than 0';
  }
  if (min != null && !(min >= 0)) errors.minSubtotal = 'Cannot be negative';
  if (f.discountType === 'FIXED' && amount > 0 && min != null && min > 0 && amount > min) {
    errors.amountOff = 'Should not be more than the minimum subtotal';
  }
  if (usage != null && (!Number.isInteger(usage) || usage < 1)) errors.usageLimit = 'Whole number, at least 1';
  if (perCustomer != null && (!Number.isInteger(perCustomer) || perCustomer < 1)) errors.perCustomerLimit = 'Whole number, at least 1';
  if (usage != null && perCustomer != null && perCustomer > usage) errors.perCustomerLimit = 'Cannot exceed the total limit';
  if (f.startsAt && f.expiresAt && f.expiresAt < f.startsAt) errors.expiresAt = 'Must be on or after the start date';

  const body = {
    code,
    description: f.description.trim() || null,
    discountType: f.discountType,
    percentOff: f.discountType === 'PERCENT' ? percent : null,
    amountOff: f.discountType === 'FIXED' ? amount : null,
    maxDiscount: f.discountType === 'PERCENT' ? max : null,
    minSubtotal: min ?? 0,
    startsAt: startOfDay(f.startsAt),
    expiresAt: endOfDay(f.expiresAt),
    usageLimit: usage,
    perCustomerLimit: perCustomer,
    active: f.active,
  };
  return { errors, body };
};

const Field = ({ label, hint, error, children, className = '' }) => (
  <label className={`flex flex-col gap-1 text-sm ${className}`}>
    <span className="text-gray-600">{label}</span>
    {children}
    {error ? <span className="text-xs text-red-600">{error}</span> : hint && <span className="text-xs text-gray-400">{hint}</span>}
  </label>
);

const inputClass = (error) => `border rounded px-3 py-2 bg-white ${error ? 'border-red-400' : 'border-gray-300'}`;

const CouponForm = ({ editing, onSaved, onCancel }) => {
  const [form, setForm] = useState(editing ? fromCoupon(editing) : EMPTY_FORM);
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
                <input type="number" min="1" max="90" step="1" value={form.percentOff} onChange={set('percentOff')} className={inputClass(errors.percentOff)} />
              </Field>
              <Field label="Max discount ($)" error={errors.maxDiscount} hint="Optional cap per order">
                <input type="number" min="0.01" step="0.01" value={form.maxDiscount} onChange={set('maxDiscount')} placeholder="No cap" className={inputClass(errors.maxDiscount)} />
              </Field>
            </>
          ) : (
            <Field label="Amount off ($)" error={errors.amountOff} className="lg:col-span-2">
              <input type="number" min="0.01" step="0.01" value={form.amountOff} onChange={set('amountOff')} placeholder="5.00" className={inputClass(errors.amountOff)} />
            </Field>
          )}

          <Field label="Minimum subtotal ($)" error={errors.minSubtotal} hint="Items total before shipping">
            <input type="number" min="0" step="0.01" value={form.minSubtotal} onChange={set('minSubtotal')} placeholder="No minimum" className={inputClass(errors.minSubtotal)} />
          </Field>

          <Field label="Starts on" hint="Leave empty to start now">
            <input type="date" value={form.startsAt} onChange={set('startsAt')} className={inputClass()} />
          </Field>
          <Field label="Expires after" error={errors.expiresAt} hint="Valid through the end of this day">
            <input type="date" value={form.expiresAt} min={form.startsAt || undefined} onChange={set('expiresAt')} className={inputClass(errors.expiresAt)} />
          </Field>
          <Field label="Total uses" error={errors.usageLimit} hint="Leave empty for unlimited">
            <input type="number" min="1" step="1" value={form.usageLimit} onChange={set('usageLimit')} placeholder="Unlimited" className={inputClass(errors.usageLimit)} />
          </Field>
          <Field label="Uses per customer" error={errors.perCustomerLimit} hint="Leave empty for unlimited">
            <input type="number" min="1" step="1" value={form.perCustomerLimit} onChange={set('perCustomerLimit')} placeholder="Unlimited" className={inputClass(errors.perCustomerLimit)} />
          </Field>
        </div>

        <div className="flex flex-wrap items-center justify-between gap-3 mt-5 pt-4 border-t">
          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={form.active} onChange={set('active')} className="accent-black" />
            Active (customers can use it)
          </label>
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
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [sort, onSort] = useSort('created', 'desc', (key) => (key === 'code' ? 'asc' : 'desc'));
  const reload = () => setVersion((v) => v + 1);

  const coupons = useMemo(() => data || [], [data]);

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

  const stats = useMemo(
    () => ({
      active: coupons.filter((c) => c.status === 'ACTIVE').length,
      uses: coupons.reduce((sum, c) => sum + c.timesUsed, 0),
      given: coupons.reduce((sum, c) => sum + Number(c.totalDiscount), 0),
    }),
    [coupons],
  );

  const openNew = () => {
    setEditing(null);
    setFormOpen(true);
  };
  const openEdit = (c) => {
    setEditing(c);
    setFormOpen(true);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };
  const closeForm = () => {
    setFormOpen(false);
    setEditing(null);
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
          onCancel={closeForm}
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
            <SearchInput value={search} onChange={setSearch} placeholder="Search code or description" />
            <select value={status} onChange={(e) => setStatus(e.target.value)} className="border border-gray-300 rounded px-3 py-2 text-sm bg-white">
              <option value="">All statuses</option>
              {Object.entries(STATUS_STYLE).map(([value, [label]]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
            <span className="text-sm text-gray-500">{visible.length} coupons</span>
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
                    <SortTh label="Used" sortKey="used" sort={sort} onSort={onSort} />
                    <SortTh label="Given" sortKey="given" sort={sort} onSort={onSort} className="hidden md:table-cell" />
                    <SortTh label="Expires" sortKey="expires" sort={sort} onSort={onSort} className="hidden md:table-cell" />
                    <th className="px-4 py-3 font-normal">Status</th>
                    <th className="px-4 py-3 font-normal text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y">
                  {visible.map((c) => {
                    const [label, color] = STATUS_STYLE[c.status] || [c.status, 'bg-gray-100 text-gray-600'];
                    const conditions = [
                      Number(c.minSubtotal) > 0 && `Min. ${money(c.minSubtotal)}`,
                      c.perCustomerLimit && `${c.perCustomerLimit}× per customer`,
                      c.startsAt && `From ${shortDate(c.startsAt)}`,
                    ].filter(Boolean);
                    return (
                      <tr key={c.id} className={c.status === 'ACTIVE' ? '' : 'bg-gray-50/60'}>
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
                          {c.timesUsed}
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
                          <span className={`inline-block px-2.5 py-1 rounded-full text-xs font-medium whitespace-nowrap ${color}`}>{label}</span>
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
        </>
      )}
    </>
  );
};

export default Coupons;
