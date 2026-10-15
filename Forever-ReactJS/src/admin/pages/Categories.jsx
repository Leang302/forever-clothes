import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import useApi from "../../components/useApi";
import useUnsavedChanges from "../../components/useUnsavedChanges";
import { Card, ClearFilters, Dropdown, Empty, ErrorText, Loading, PageTitle, Pagination, SearchInput, Segmented } from "../components/ui";
import { money } from "../format";
import { matches, sortRows, usePage, useUrlFilters, useUrlSearch } from "../table";
import { useOnProductSaved, useOpenProduct } from "../productDrawer";
import { NAME_MAX, categoryName, validate, z } from "@/lib/validation";

const PAGE_SIZE = 8;
// NAME_MAX and the name rules come from @/lib/validation (same as the API).
const PRODUCT_SORTS = [
  ['newest', 'Newest'],
  ['name_asc', 'Name A–Z'],
  ['price_asc', 'Price: low to high'],
  ['price_desc', 'Price: high to low'],
  ['stock_asc', 'Stock: low to high'],
];

// URL query params: `id` = selected category, `filter`/`order` = category list,
// `sub`/`q`/`visibility`/`sort` = the selected category's products.
const FILTER_DEFAULTS = { id: '', filter: '', order: 'name', sub: '', q: '', visibility: 'all', sort: 'newest' };
const PRODUCT_FILTERS_RESET = { sub: '', q: '', visibility: 'all', sort: 'newest' };

const plural = (n, word, many = `${word}s`) => `${n} ${n === 1 ? word : many}`;

// Same rules as the API: trimmed, single spaces, 1–40 characters, letters/numbers/spaces/&'- and unique ignoring case
// among `siblings` (all categories, or the sub-categories of one category).
const normalizeName = (raw) => raw.trim().replace(/\s+/g, ' ');
const nameError = (raw, siblings, exceptId) => {
  const schema = categoryName.superRefine((name, ctx) => {
    const clash = siblings.find((s) => s.id !== exceptId && s.name.toLowerCase() === name.toLowerCase());
    if (clash) ctx.addIssue({ code: z.ZodIssueCode.custom, message: `"${clash.name}" already exists` });
  });
  return validate(schema, raw).errors._form ?? null;
};

// Small "name + Add" form with live validation.
const AddNameForm = ({ id, label, placeholder, siblings, help, onAdd }) => {
  const [name, setName] = useState('');
  const [saving, setSaving] = useState(false);
  const { dialog: leaveDialog } = useUnsavedChanges(name.trim() !== '', `The new ${label.toLowerCase()} has not been added yet. Leave and discard it?`);
  const error = name ? nameError(name, siblings) : null;

  const submit = async (e) => {
    e.preventDefault();
    if (!name.trim() || error) return;
    setSaving(true);
    try {
      await onAdd(normalizeName(name));
      setName('');
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={submit} noValidate>
      <label htmlFor={id} className="block text-sm text-gray-600 mb-1">
        {label}
      </label>
      <div className="flex gap-2">
        <input
          id={id}
          value={name}
          onChange={(e) => setName(e.target.value)}
          aria-invalid={Boolean(error)}
          aria-describedby={`${id}-help`}
          placeholder={placeholder}
          className={`border rounded px-3 py-2 text-sm bg-white flex-1 min-w-0 ${error ? 'border-red-400' : 'border-gray-300'}`}
        />
        <button disabled={saving || !name.trim() || Boolean(error)} className="bg-black text-white text-sm px-4 py-2 rounded disabled:opacity-50">
          {saving ? 'Adding...' : 'Add'}
        </button>
      </div>
      <p id={`${id}-help`} className={`text-xs mt-2 ${error ? 'text-red-600' : 'text-gray-400'}`}>
        {error || help}
      </p>
      {leaveDialog}
    </form>
  );
};

// Modal that optionally asks for a target (e.g. where to move products). Escape or the backdrop closes it.
// `targets` is a list of [id, label]; `message` null means no target is needed.
const MoveDialog = ({ title, message, plainMessage, targets, targetLabel, emptyText, confirmLabel, danger, onCancel, onConfirm }) => {
  const [targetId, setTargetId] = useState('');
  const [busy, setBusy] = useState(false);
  const needsTarget = message != null;

  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && !busy && onCancel();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [busy, onCancel]);

  const confirm = async () => {
    setBusy(true);
    try {
      await onConfirm(needsTarget ? Number(targetId) : null);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-[1100] flex items-center justify-center bg-black/50 px-4"
      onMouseDown={(e) => e.target === e.currentTarget && !busy && onCancel()}
    >
      <div role="dialog" aria-modal="true" aria-labelledby="move-title" className="w-full max-w-md rounded-lg bg-white p-6 shadow-2xl">
        <h2 id="move-title" className="text-lg font-semibold text-gray-900">{title}</h2>
        {needsTarget ? (
          <>
            <p className="mt-2 text-sm leading-6 text-gray-600">{message}</p>
            {targets.length === 0 ? (
              <p className="mt-4 rounded bg-amber-50 px-3 py-2 text-sm text-amber-800">{emptyText}</p>
            ) : (
              <div className="mt-4">
                <span id="move-target" className="block text-sm text-gray-600 mb-1.5">{targetLabel}</span>
                <Dropdown
                  aria-labelledby="move-target"
                  value={targetId}
                  onChange={setTargetId}
                  options={targets.map(([id, label]) => [String(id), label])}
                  placeholder="Choose one"
                  contentClassName="z-[1200]"
                />
              </div>
            )}
          </>
        ) : (
          <p className="mt-2 text-sm leading-6 text-gray-600">{plainMessage}</p>
        )}
        <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <button type="button" onClick={onCancel} disabled={busy} autoFocus
            className="rounded border border-gray-300 px-5 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">
            Cancel
          </button>
          <button type="button" onClick={confirm} disabled={busy || (needsTarget && !targetId)}
            className={`rounded px-5 py-2.5 text-sm font-medium text-white disabled:opacity-40 ${danger ? 'bg-red-600 hover:bg-red-700' : 'bg-black hover:bg-gray-800'}`}>
            {busy ? 'Working...' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
};

// Bulk move target: a category (the current one too) and one of its sub-categories, both required.
const moveSchema = z.object({
  targetId: z.string().min(1, 'Choose a category'),
  subId: z.string().min(1, 'Choose a sub-category'),
});

// Bulk move dialog, also used to delete a category that still has products (`deleting`: the products go to
// another category's sub-category, then the category is deleted). `onConfirm({ targetId, targetSubCategoryId })`
// returns a promise.
const MoveProductsDialog = ({ source, count, selectedOnly, deleting = false, categories, onCancel, onConfirm }) => {
  const [targetId, setTargetId] = useState(deleting ? '' : String(source.id));
  const [subId, setSubId] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [busy, setBusy] = useState(false);
  const { data: subs, loading } = useApi(
    () => (targetId ? api.adminSubCategories(Number(targetId)) : Promise.resolve([])),
    [targetId],
  );
  const targets = deleting ? categories.filter((c) => c.id !== source.id) : categories;
  const target = categories.find((c) => String(c.id) === targetId);
  const noSubs = Boolean(targetId) && !loading && subs?.length === 0;
  const errors = submitted ? validate(moveSchema, { targetId, subId }).errors : {};

  useEffect(() => {
    const onKey = (e) => e.key === 'Escape' && !busy && onCancel();
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [busy, onCancel]);

  const confirm = async () => {
    setSubmitted(true);
    const { data } = validate(moveSchema, { targetId, subId });
    if (!data) return;
    setBusy(true);
    try {
      await onConfirm({ targetId: Number(data.targetId), targetSubCategoryId: Number(data.subId) });
    } finally {
      setBusy(false);
    }
  };

  const sub = subs?.find((s) => String(s.id) === subId);
  const hint = sub ? `They will all be in ${target?.name} › ${sub.name}.` : null;

  return (
    <div
      className="fixed inset-0 z-[1100] flex items-center justify-center bg-black/50 px-4"
      onMouseDown={(e) => e.target === e.currentTarget && !busy && onCancel()}
    >
      <div role="dialog" aria-modal="true" aria-labelledby="bulk-move-title" className="w-full max-w-md rounded-lg bg-white p-6 shadow-2xl">
        <h2 id="bulk-move-title" className="text-lg font-semibold text-gray-900">
          {deleting ? `Delete "${source.name}"?` : `Move ${plural(count, 'product')}`}
        </h2>
        <p className="mt-2 text-sm leading-6 text-gray-600">
          {deleting
            ? `"${source.name}" still has ${plural(count, 'product')}. Choose where they go; "${source.name}" and its sub-categories are deleted afterwards.`
            : selectedOnly
              ? `Move the selected ${plural(count, 'product')} from "${source.name}".`
              : `Move every product in "${source.name}".`}
        </p>
        {deleting && targets.length === 0 && (
          <p className="mt-4 rounded bg-amber-50 px-3 py-2 text-sm text-amber-800">
            There is no other category yet. Add one first, then move the products into it.
          </p>
        )}

        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <div>
            <span id="bulk-move-category" className="block text-sm text-gray-600 mb-1.5">Category</span>
            <Dropdown
              aria-labelledby="bulk-move-category"
              value={targetId}
              onChange={(v) => {
                setTargetId(v);
                setSubId(''); // sub-categories belong to a category
              }}
              options={targets.map((c) => [String(c.id), c.id === source.id ? `${c.name} (current)` : c.name])}
              placeholder="Choose a category"
              aria-invalid={Boolean(errors.targetId)}
              className={errors.targetId ? 'border-red-400' : ''}
              contentClassName="z-[1200]"
            />
            {errors.targetId && <p className="text-xs text-red-600 mt-1">{errors.targetId}</p>}
          </div>
          <div>
            <span id="bulk-move-sub" className="block text-sm text-gray-600 mb-1.5">Sub-category</span>
            <Dropdown
              aria-labelledby="bulk-move-sub"
              value={subId}
              onChange={setSubId}
              disabled={!targetId || loading || noSubs}
              placeholder={!targetId ? 'Choose a category first' : loading ? 'Loading...' : noSubs ? 'None yet' : 'Choose one'}
              options={(subs || []).map((s) => [String(s.id), `${s.name} (${plural(s.productCount, 'product')})`])}
              aria-invalid={Boolean(errors.subId)}
              className={errors.subId ? 'border-red-400' : ''}
              contentClassName="z-[1200]"
            />
            {errors.subId && !noSubs && <p className="text-xs text-red-600 mt-1">{errors.subId}</p>}
          </div>
        </div>
        {noSubs ? (
          <p className="mt-3 rounded bg-amber-50 px-3 py-2 text-xs text-amber-800">
            {target?.name} has no sub-categories yet. Add one on this page first, then move the products into it.
          </p>
        ) : (
          hint && <p className="mt-3 text-xs text-gray-500">{hint}</p>
        )}

        <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <button type="button" onClick={onCancel} disabled={busy} autoFocus
            className="rounded border border-gray-300 px-5 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50">
            Cancel
          </button>
          <button type="button" onClick={confirm} disabled={busy || noSubs || (deleting && targets.length === 0)}
            className={`rounded px-5 py-2.5 text-sm font-medium text-white disabled:opacity-40 ${deleting ? 'bg-red-600 hover:bg-red-700' : 'bg-black hover:bg-gray-800'}`}>
            {busy ? (deleting ? 'Deleting...' : 'Moving...') : deleting ? 'Move and delete' : 'Move'}
          </button>
        </div>
      </div>
    </div>
  );
};

// One row of a category or sub-category list, with inline rename. `onRename(name)` returns a promise.
const NameRow = ({ item, siblings, detail, isSelected, onSelect, onRename, onDelete }) => {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(item.name);
  const [saving, setSaving] = useState(false);
  const error = editing ? nameError(draft, siblings, item.id) : null;

  const save = async (e) => {
    e.preventDefault();
    if (error) return;
    if (normalizeName(draft) === item.name) return setEditing(false);
    setSaving(true);
    try {
      await onRename(normalizeName(draft));
      setEditing(false);
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSaving(false);
    }
  };

  if (editing) {
    return (
      <li className="px-4 py-3 bg-gray-50">
        <form onSubmit={save} className="flex flex-col gap-1">
          <div className="flex gap-2">
            <input
              autoFocus
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => e.key === 'Escape' && setEditing(false)}
              aria-label={`New name for ${item.name}`}
              aria-invalid={Boolean(error)}
              className={`border rounded px-2 py-1.5 text-sm bg-white flex-1 min-w-0 ${error ? 'border-red-400' : 'border-gray-300'}`}
            />
            <button disabled={saving || Boolean(error)} className="bg-black text-white text-sm px-3 rounded disabled:opacity-40">
              {saving ? 'Saving...' : 'Save'}
            </button>
            <button type="button" onClick={() => setEditing(false)} className="text-sm text-gray-500 hover:underline">
              Cancel
            </button>
          </div>
          {error && <p className="text-xs text-red-600">{error}</p>}
          {!error && item.productCount > 0 && (
            <p className="text-xs text-gray-400">{plural(item.productCount, 'product')} will move to the new name.</p>
          )}
        </form>
      </li>
    );
  }

  return (
    <li className={`flex items-center gap-2 px-4 py-3 ${isSelected ? 'bg-gray-100' : 'hover:bg-gray-50'}`}>
      <button type="button" onClick={onSelect} className="flex-1 min-w-0 text-left">
        <p className={`truncate ${isSelected ? 'font-semibold' : 'font-medium'}`}>{item.name}</p>
        <p className="text-xs text-gray-500">{detail}</p>
      </button>
      <button
        type="button"
        onClick={() => {
          setDraft(item.name);
          setEditing(true);
        }}
        className="text-sm text-gray-600 hover:underline"
      >
        Rename
      </button>
      <button type="button" onClick={onDelete} className="text-sm text-red-600 hover:underline">
        Delete
      </button>
    </li>
  );
};

// Sub-categories of the selected category as compact filter chips; "Manage" opens add / rename / delete.
const SubCategories = ({ category, subs, loading, error, selectedSub, onSelectSub, onChanged, onDelete }) => {
  const [managing, setManaging] = useState(false);
  const showManage = managing || (!loading && !error && subs.length === 0);
  const total = subs.reduce((sum, s) => sum + s.productCount, 0);
  const chip = (active) =>
    `inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-sm transition-colors ${
      active ? 'border-black bg-black text-white' : 'border-gray-300 bg-white text-gray-700 hover:border-gray-500'
    }`;

  return (
    <Card className="overflow-hidden">
      <div className="flex items-center justify-between gap-3 px-4 pt-3">
        <h2 className="text-sm font-medium text-gray-700">Sub-categories in {category.name}</h2>
        {subs.length > 0 && (
          <button type="button" onClick={() => setManaging((m) => !m)} aria-expanded={showManage} className="text-sm text-gray-600 hover:underline">
            {managing ? 'Done' : 'Manage'}
          </button>
        )}
      </div>
      {loading && !subs.length && <Loading />}
      <ErrorText error={error} />
      {subs.length > 0 && (
        <div className="flex flex-wrap gap-2 px-4 py-3">
          <button type="button" onClick={() => onSelectSub('')} className={chip(!selectedSub)} aria-pressed={!selectedSub}>
            All <span className={!selectedSub ? 'text-gray-300' : 'text-gray-400'}>{total}</span>
          </button>
          {subs.map((s) => (
            <button
              key={s.id}
              type="button"
              onClick={() => onSelectSub(selectedSub === s.name ? '' : s.name)}
              className={chip(selectedSub === s.name)}
              aria-pressed={selectedSub === s.name}
            >
              {s.name} <span className={selectedSub === s.name ? 'text-gray-300' : 'text-gray-400'}>{s.productCount}</span>
            </button>
          ))}
        </div>
      )}
      {showManage && <ManageSubCategories category={category} subs={subs} loading={loading} error={error}
        selectedSub={selectedSub} onSelectSub={onSelectSub} onChanged={onChanged} onDelete={onDelete} />}
    </Card>
  );
};

// Add / rename / delete sub-categories (opened with "Manage").
const ManageSubCategories = ({ category, subs, loading, error, selectedSub, onSelectSub, onChanged, onDelete }) => (
  <div className="border-t bg-gray-50/60">
    <div className="p-4 border-b">
      <AddNameForm
        key={category.id}
        id="sub-category-name"
        label={`New sub-category in ${category.name}`}
        placeholder="e.g. Accessories"
        siblings={subs}
        help={`Up to ${NAME_MAX} characters. Products in ${category.name} choose from these.`}
        onAdd={async (name) => {
          const created = await api.adminAddSubCategory(category.id, name);
          toast.success(`Sub-category "${created.name}" added to ${category.name}`);
          onChanged();
        }}
      />
    </div>
    {!loading && !error && subs.length === 0 && <Empty>No sub-categories in {category.name} yet. Add the first one above.</Empty>}
    {subs.length > 0 && (
      <>
        <ul className="divide-y max-h-72 overflow-y-auto">
          {subs.map((s) => (
            <NameRow
              key={s.id}
              item={s}
              siblings={subs}
              detail={plural(s.productCount, 'product')}
              isSelected={selectedSub === s.name}
              onSelect={() => onSelectSub(selectedSub === s.name ? '' : s.name)}
              onRename={async (name) => {
                const updated = await api.adminRenameSubCategory(s.id, name);
                toast.success(`Renamed to "${updated.name}"${s.productCount ? ` (${plural(s.productCount, 'product')} updated)` : ''}`);
                if (selectedSub === s.name) onSelectSub(updated.name);
                onChanged();
              }}
              onDelete={() => onDelete(s)}
            />
          ))}
        </ul>
      </>
    )}
  </div>
);

// Products belonging to one category, with sub-category, search, visibility and sort filters, multi-select and "Move to".
const CategoryProducts = ({ category, filters, setFilters, version, onMove }) => {
  const openProduct = useOpenProduct();
  const [search, setSearch] = useUrlSearch(filters, setFilters);
  const { sub, q, visibility, sort } = filters;
  const [page, setPage] = usePage(JSON.stringify([sub, q, visibility, sort]));
  const [selected, setSelected] = useState(() => new Set());

  // A new search, filter, page or a finished move starts a fresh selection.
  useEffect(() => setSelected(new Set()), [sub, q, visibility, sort, page, version]);

  const { data, loading, error } = useApi(
    () =>
      api.adminProducts({
        category: category.name,
        subCategory: sub || undefined,
        q: q || undefined,
        active: visibility === 'all' ? undefined : visibility === 'visible',
        sort,
        page,
        size: PAGE_SIZE,
      }),
    [category.name, sub, q, visibility, sort, page, version],
  );
  const items = data?.content || [];
  const allOnPage = items.length > 0 && items.every((p) => selected.has(p.id));
  const toggle = (id) =>
    setSelected((s) => {
      const next = new Set(s);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  const togglePage = () => setSelected(allOnPage ? new Set() : new Set(items.map((p) => p.id)));
  const narrowed = sub || q || visibility !== 'all';
  // Changing page from the pager at the bottom brings the list back into view.
  const topRef = useRef(null);
  const goToPage = (p) => {
    setPage(p);
    topRef.current?.scrollIntoView({ block: 'start', behavior: 'smooth' });
  };

  return (
    <>
    <div ref={topRef} className="scroll-mt-20" aria-hidden="true" />
    {/* overflow-clip (not hidden) so the selection bar below can stick to the top while scrolling */}
    <Card className="overflow-clip">
      <div className="flex flex-wrap items-center justify-between gap-3 p-4 border-b">
        <div>
          <h2 className="font-medium">
            {category.name}
            {sub && <span className="text-gray-400"> › {sub}</span>}
          </h2>
          <p className="text-xs text-gray-500">
            {plural(category.productCount, 'product')}
            {data && narrowed && ` · ${data.totalElements} matching`}
          </p>
        </div>
        <div className="flex items-center gap-2">
          {category.productCount > 0 && (
            <button type="button" onClick={() => onMove(null)}
              className="border border-gray-300 rounded px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 whitespace-nowrap">
              Move all…
            </button>
          )}
          <button
            type="button"
            onClick={() => openProduct('new', { category: category.name, subCategory: sub })}
            title={`New product in ${category.name}${sub ? ` › ${sub}` : ''}`}
            className="bg-black text-white text-sm px-4 py-2 rounded whitespace-nowrap"
          >
            + Add product{sub ? ` to ${sub}` : ''}
          </button>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2 p-4 border-b bg-gray-50">
        <SearchInput value={search} onChange={setSearch} placeholder={`Search in ${category.name}`} className="w-full sm:w-56" />
        <Segmented
          value={visibility}
          onChange={(v) => setFilters({ visibility: v })}
          options={[
            ['all', 'All'],
            ['visible', 'Visible'],
            ['hidden', 'Hidden'],
          ]}
        />
        <Dropdown value={sort} onChange={(v) => setFilters({ sort: v })} options={PRODUCT_SORTS} aria-label="Sort products"
          className="w-auto min-w-[10rem] h-[38px]" />
        {(narrowed || search) && (
          <ClearFilters
            count={[sub, search, visibility !== 'all'].filter(Boolean).length}
            onClick={() => {
              setSearch('');
              setFilters({ sub: '', q: '', visibility: 'all' });
            }}
          />
        )}
      </div>

      {selected.size > 0 && (
        <div className="sticky top-14 z-10 flex flex-wrap items-center justify-between gap-2 px-4 py-2 border-b bg-black text-white text-sm shadow">
          <span>{plural(selected.size, 'product')} selected</span>
          <div className="flex items-center gap-3">
            <button type="button" onClick={() => setSelected(new Set())} className="text-gray-300 hover:text-white">
              Clear
            </button>
            <button type="button" onClick={() => onMove([...selected])} className="bg-white text-black rounded px-3 py-1.5 font-medium">
              Move to…
            </button>
          </div>
        </div>
      )}

      {loading && <Loading />}
      <ErrorText error={error} />
      {!loading && !error && items.length === 0 && (
        <Empty>{narrowed ? 'No matching products' : 'No products in this category yet'}</Empty>
      )}

      {!loading && items.length > 0 && (
        <>
          <label className="flex items-center gap-3 px-4 py-2 border-b text-xs text-gray-500 cursor-pointer">
            <input type="checkbox" checked={allOnPage} onChange={togglePage} className="accent-black" />
            Select all on this page
          </label>
          <ul className="divide-y">
            {items.map((p) => (
              <li key={p.id} className={`flex items-center gap-3 px-4 py-3 ${selected.has(p.id) ? 'bg-gray-100' : p.active ? '' : 'bg-gray-50'}`}>
                <input type="checkbox" checked={selected.has(p.id)} onChange={() => toggle(p.id)} aria-label={`Select ${p.name}`} className="accent-black" />
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
                <button
                  type="button"
                  onClick={() => openProduct(p.id)}
                  className="border border-gray-300 rounded px-3 py-1 text-sm text-gray-700 hover:bg-gray-100 bg-white"
                >
                  Edit
                </button>
              </li>
            ))}
          </ul>
        </>
      )}

      <div className="px-4 pb-4">
        <Pagination page={page} totalPages={data?.totalPages || 0} total={data?.totalElements} pageSize={data?.size} onChange={goToPage} />
      </div>
    </Card>
    </>
  );
};

const Categories = () => {
  const [filters, setFilters] = useUrlFilters(FILTER_DEFAULTS);
  const [version, setVersion] = useState(0);
  // { kind: 'move' | 'delete' | 'deleteSub', source, productIds }
  const [dialog, setDialog] = useState(null);

  const { data, loading, error } = useApi(() => api.adminCategories(), [version]);
  const all = useMemo(() => data || [], [data]);
  const refresh = useCallback(() => setVersion((v) => v + 1), []);
  useOnProductSaved(refresh); // counts and lists change when a product is added or edited in the drawer

  const categories = useMemo(() => {
    const list = all.filter((c) => matches(filters.filter, c.name));
    return filters.order === 'count'
      ? sortRows(list, { key: 'count', dir: 'desc' }, { count: (c) => c.productCount ?? 0 })
      : sortRows(list, { key: 'name', dir: 'asc' }, { name: (c) => c.name });
  }, [all, filters.filter, filters.order]);
  const selected = all.find((c) => String(c.id) === filters.id) || categories[0];
  // On narrow screens the products are below the list, so picking a category scrolls to them.
  const detailRef = useRef(null);
  const select = (c, { scroll = false } = {}) => {
    setFilters({ id: c ? String(c.id) : '', ...PRODUCT_FILTERS_RESET });
    if (scroll && window.matchMedia('(max-width: 1023px)').matches) {
      requestAnimationFrame(() => detailRef.current?.scrollIntoView({ block: 'start', behavior: 'smooth' }));
    }
  };

  const subsApi = useApi(() => (selected ? api.adminSubCategories(selected.id) : Promise.resolve([])), [selected?.id, version]);
  const subs = subsApi.data || [];

  const moveProducts = async ({ targetId, targetSubCategoryId }) => {
    const { source, productIds } = dialog;
    try {
      const { moved, target, subCategory } = await api.adminMoveCategoryProducts(source.id, {
        targetId,
        targetSubCategoryId,
        productIds: productIds || undefined,
      });
      toast.success(`Moved ${plural(moved, 'product')} to "${target}${subCategory ? ` › ${subCategory}` : ''}"`);
      setDialog(null);
      refresh();
    } catch (err) {
      toast.error(err.message);
      if (err.code === 'PRODUCTS_CHANGED') refresh();
    }
  };

  // `move` is { targetId, targetSubCategoryId } while the category has products, null when it is empty.
  const deleteCategory = async (move) => {
    const { source } = dialog;
    try {
      await api.adminDeleteCategory(source.id, move?.targetId, move?.targetSubCategoryId);
      const target = move && all.find((c) => c.id === move.targetId);
      toast.success(
        target
          ? `Moved ${plural(source.productCount, 'product')} to "${target.name}" and deleted "${source.name}"`
          : `Category "${source.name}" deleted`,
      );
      setDialog(null);
      if (selected?.id === source.id) select(target || null);
      refresh();
    } catch (err) {
      toast.error(err.message);
    }
  };

  const deleteSubCategory = async (targetId) => {
    const { source } = dialog;
    try {
      await api.adminDeleteSubCategory(source.id, targetId ?? undefined);
      const target = subs.find((s) => s.id === targetId);
      toast.success(
        target
          ? `Moved ${plural(source.productCount, 'product')} to "${target.name}" and deleted "${source.name}"`
          : `Sub-category "${source.name}" deleted`,
      );
      setDialog(null);
      if (filters.sub === source.name) setFilters({ sub: '' });
      refresh();
    } catch (err) {
      toast.error(err.message);
    }
  };

  const categoryTargets = (source) =>
    all.filter((c) => c.id !== source.id).map((c) => [c.id, `${c.name} (${plural(c.productCount, 'product')})`]);

  const dialogProps = () => {
    const { kind, source } = dialog;
    if (kind === 'deleteSub') {
      return {
        title: `Delete "${source.name}"?`,
        message: source.productCount > 0
          ? `"${source.name}" still has ${plural(source.productCount, 'product')}. Choose another ${selected.name} sub-category for them; "${source.name}" is deleted afterwards.`
          : null,
        plainMessage: `"${source.name}" has no products. This cannot be undone.`,
        targets: subs.filter((s) => s.id !== source.id).map((s) => [s.id, `${s.name} (${plural(s.productCount, 'product')})`]),
        targetLabel: 'Move products to',
        emptyText: `${selected.name} has no other sub-category yet. Add one first, then move the products into it.`,
        confirmLabel: source.productCount > 0 ? 'Move and delete' : 'Delete',
        danger: true,
        onConfirm: deleteSubCategory,
      };
    }
    if (kind === 'delete') {
      return {
        title: `Delete "${source.name}"?`,
        message: source.productCount > 0
          ? `"${source.name}" still has ${plural(source.productCount, 'product')}. Choose where to move them; the category and its sub-categories are deleted afterwards.`
          : null,
        plainMessage: `"${source.name}" has no products. Its sub-categories are deleted too. This cannot be undone.`,
        targets: categoryTargets(source),
        targetLabel: 'Move products to',
        emptyText: 'There is no other category yet. Add one first, then move the products into it.',
        confirmLabel: source.productCount > 0 ? 'Move and delete' : 'Delete',
        danger: true,
        onConfirm: deleteCategory,
      };
    }
    return null; // 'move' uses MoveProductsDialog
  };

  return (
    <>
      <PageTitle title="Categories">
        {data && <span className="text-sm text-gray-500">{plural(data.length, 'category', 'categories')}</span>}
      </PageTitle>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3 lg:items-start">
        {/* On wide screens this column stays in view and its category list scrolls on its own. */}
        <div className="flex flex-col gap-4 min-w-0 lg:sticky lg:top-[4.5rem] lg:max-h-[calc(100vh-5.5rem)]">
          <Card className="p-4 shrink-0">
            <AddNameForm
              id="category-name"
              label="New category"
              placeholder="e.g. Accessories"
              siblings={all}
              help={`Up to ${NAME_MAX} characters. Products choose from these categories.`}
              onAdd={async (name) => {
                const created = await api.adminAddCategory(name);
                toast.success(`Category "${created.name}" added. Now add its sub-categories.`);
                select(created);
                refresh();
              }}
            />
          </Card>

          <Card className="overflow-hidden flex flex-col min-h-0 lg:flex-1">
            <div className="flex items-center gap-2 p-3 border-b shrink-0">
              <SearchInput value={filters.filter} onChange={(v) => setFilters({ filter: v })} placeholder="Filter categories" className="flex-1" />
              <Dropdown
                value={filters.order}
                onChange={(v) => setFilters({ order: v })}
                options={[
                  ['name', 'A–Z'],
                  ['count', 'Most products'],
                ]}
                aria-label="Sort categories"
                className="w-auto min-w-[8rem] h-[38px]"
              />
            </div>
            {loading && <Loading />}
            <ErrorText error={error} />
            {!loading && !error && categories.length === 0 && <Empty>{all.length ? 'No match' : 'No categories yet'}</Empty>}
            {categories.length > 0 && (
              <ul className="divide-y overflow-y-auto max-h-[60vh] lg:max-h-none lg:min-h-0 lg:flex-1">
                {categories.map((c) => {
                  const hidden = c.productCount - c.activeProductCount;
                  return (
                    <NameRow
                      key={c.id}
                      item={c}
                      siblings={all}
                      detail={`${plural(c.productCount, 'product')}${hidden > 0 ? ` · ${hidden} hidden` : ''}`}
                      isSelected={selected?.id === c.id}
                      onSelect={() => select(c, { scroll: true })}
                      onRename={async (name) => {
                        const updated = await api.adminRenameCategory(c.id, name);
                        toast.success(`Renamed to "${updated.name}"${c.productCount ? ` (${plural(c.productCount, 'product')} updated)` : ''}`);
                        refresh();
                      }}
                      onDelete={() => setDialog({ kind: 'delete', source: c })}
                    />
                  );
                })}
              </ul>
            )}
          </Card>
        </div>

        <div ref={detailRef} className="lg:col-span-2 min-w-0 flex flex-col gap-4 scroll-mt-20">
          {selected ? (
            <>
              <SubCategories
                key={`subs-${selected.id}`}
                category={selected}
                subs={subs}
                loading={subsApi.loading && !subsApi.data}
                error={subsApi.error}
                selectedSub={filters.sub}
                onSelectSub={(sub) => setFilters({ sub })}
                onChanged={refresh}
                onDelete={(s) => setDialog({ kind: 'deleteSub', source: s })}
              />
              <CategoryProducts
                key={`products-${selected.id}`}
                category={selected}
                filters={filters}
                setFilters={setFilters}
                version={version}
                onMove={(productIds) => setDialog({ kind: 'move', source: selected, productIds })}
              />
            </>
          ) : (
            !loading && (
              <Card>
                <Empty>Select a category to see its sub-categories and products</Empty>
              </Card>
            )
          )}
        </div>
      </div>

      {(dialog?.kind === 'move' || (dialog?.kind === 'delete' && dialog.source.productCount > 0)) && (
        <MoveProductsDialog
          key={`${dialog.kind}-${dialog.source.id}`}
          source={dialog.source}
          count={dialog.productIds ? dialog.productIds.length : dialog.source.productCount}
          selectedOnly={Boolean(dialog.productIds)}
          deleting={dialog.kind === 'delete'}
          categories={all}
          onCancel={() => setDialog(null)}
          onConfirm={dialog.kind === 'delete' ? deleteCategory : moveProducts}
        />
      )}
      {dialog && dialog.kind !== 'move' && !(dialog.kind === 'delete' && dialog.source.productCount > 0) && (
        <MoveDialog key={`${dialog.kind}-${dialog.source.id}`} onCancel={() => setDialog(null)} {...dialogProps()} />
      )}
    </>
  );
};

export default Categories;
