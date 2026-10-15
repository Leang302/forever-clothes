import { useEffect, useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import { assets } from "../../assets/admin_assets/assets";
import { Card, Dropdown, ErrorText, Loading } from "../components/ui";
import useUnsavedChanges from "../../components/useUnsavedChanges";
import ConfirmDialog from "../../components/ConfirmDialog";
import { text, validate, z } from "@/lib/validation";

const SIZES = ['S', 'M', 'L', 'XL', 'XXL'];
const MAX_IMAGES = 4;
const MAX_BYTES = 5 * 1024 * 1024;
const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif']; // same list the API accepts

const empty = { name: '', description: '', price: '', category: '', subCategory: '', sizes: [], bestseller: false };
// Compares the editable fields, ignoring the order sizes were clicked in.
const snapshot = (f) => JSON.stringify({ ...f, sizes: [...f.sizes].sort() });

// Same rules as the API's ProductForm. `imageCount` = newly chosen images (required when creating).
const productSchema = (editing) =>
  z.object({
    name: text('Name', 200),
    description: z.string().trim().min(1, 'Description is required'),
    price: z
      .string()
      .trim()
      .min(1, 'Price is required')
      .regex(/^\d+(\.\d{1,2})?$/, 'Enter a price like 19.99')
      .transform(Number)
      .refine((v) => v >= 0.01, 'Price must be at least $0.01'),
    category: z.string().min(1, 'Choose a category'),
    subCategory: z.string().min(1, 'Choose a sub-category'),
    sizes: z.array(z.string()).min(1, 'Select at least one size'),
    imageCount: editing ? z.number() : z.number().min(1, 'Upload at least one image'),
  });

const inputClass = (error) =>
  `w-full border rounded px-3 py-2 text-sm bg-white focus:outline-none ${error ? 'border-red-400 focus:border-red-500' : 'border-gray-300 focus:border-black'}`;

const FieldError = ({ name, error }) => (error ? <p id={`${name}-error`} className="text-xs text-red-600 mt-1">{error}</p> : null);

// Props for an input so screen readers announce its error.
const errorProps = (name, error) => ({ id: name, 'aria-invalid': Boolean(error), 'aria-describedby': error ? `${name}-error` : undefined });

const Field = ({ label, name, error, children, hint }) => (
  <label className="block" htmlFor={name}>
    <span className="block text-sm text-gray-600 mb-1.5">{label}</span>
    {children}
    <FieldError name={name} error={error} />
    {hint && !error && <span className="block text-xs text-gray-400 mt-1">{hint}</span>}
  </label>
);

/**
 * Add / edit product form, shown as a drawer over the current admin page (see ProductDrawerHost).
 * `productId` is "new" or a product id; `onClose()` closes it, `onSaved()` runs after a successful save.
 */
const ProductForm = ({ productId, prefill, onClose, onSaved }) => {
  const id = productId === 'new' ? null : productId;
  const editing = Boolean(id);

  // A new product can start with a category / sub-category (e.g. added from the Categories page).
  const [start] = useState(() => ({ ...empty, category: prefill?.category || '', subCategory: prefill?.subCategory || '' }));
  const [form, setForm] = useState(start);
  const [initial, setInitial] = useState(start); // last saved values, to detect unsaved changes
  const [files, setFiles] = useState(Array(MAX_IMAGES).fill(null)); // new uploads per slot
  const [existing, setExisting] = useState([]); // current image URLs when editing
  // Products may only use managed categories and their sub-categories; the API rejects anything else.
  const [categories, setCategories] = useState([]);
  const [subCategories, setSubCategories] = useState([]);
  const [loading, setLoading] = useState(editing);
  const [loadError, setLoadError] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.adminCategories().then((list) => setCategories([...list].sort((a, b) => a.name.localeCompare(b.name)))).catch(() => {});
  }, []);

  const categoryId = categories.find((c) => c.name === form.category)?.id;
  useEffect(() => {
    if (!categoryId) return setSubCategories([]);
    let cancelled = false;
    api.adminSubCategories(categoryId).then((list) => !cancelled && setSubCategories(list)).catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [categoryId]);

  useEffect(() => {
    if (!editing) return;
    api.adminProduct(id)
      .then((p) => {
        const loaded = {
          name: p.name, description: p.description, price: String(p.price), category: p.category,
          subCategory: p.subCategory, sizes: p.sizes, bestseller: p.bestseller,
        };
        setForm(loaded);
        setInitial(loaded);
        setExisting(p.images);
      })
      .catch(setLoadError)
      .finally(() => setLoading(false));
  }, [editing, id]);

  const previews = useMemo(() => files.map((f) => (f ? URL.createObjectURL(f) : null)), [files]);
  useEffect(() => () => previews.forEach((u) => u && URL.revokeObjectURL(u)), [previews]);

  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.value }));
  const toggleSize = (s) =>
    setForm((f) => ({ ...f, sizes: f.sizes.includes(s) ? f.sizes.filter((x) => x !== s) : [...f.sizes, s] }));

  // Puts picked or dropped images into `slot` first (replacing it), then into the empty slots after and before it.
  // `slot` null = empty slots only (a drop on the card outside the slots).
  const addFiles = (slot, list) => {
    const incoming = [...(list || [])];
    if (incoming.length === 0) return;
    const wrongType = incoming.filter((f) => !IMAGE_TYPES.includes(f.type));
    const tooBig = incoming.filter((f) => IMAGE_TYPES.includes(f.type) && f.size > MAX_BYTES);
    const ok = incoming.filter((f) => IMAGE_TYPES.includes(f.type) && f.size <= MAX_BYTES);

    const empty = files.map((f, i) => i).filter((i) => !files[i] && i !== slot);
    const targets = slot == null ? empty : [slot, ...empty.filter((i) => i > slot), ...empty.filter((i) => i < slot)];
    const placed = ok.slice(0, targets.length);
    if (placed.length) {
      setFiles((prev) => {
        const next = [...prev];
        placed.forEach((f, k) => { next[targets[k]] = f; });
        return next;
      });
    }

    if (wrongType.length) toast.error(`${wrongType.length === 1 ? `"${wrongType[0].name}" is` : `${wrongType.length} files are`} not a PNG, JPEG, WEBP or GIF image`);
    if (tooBig.length) toast.error(`${tooBig.length === 1 ? `"${tooBig[0].name}" is` : `${tooBig.length} images are`} larger than 5 MB`);
    if (ok.length > placed.length) toast.error(`Only ${MAX_IMAGES} images are allowed; ${ok.length - placed.length} not added. Remove one first.`);
  };
  const clearFile = (slot) => setFiles((prev) => prev.map((f, i) => (i === slot ? null : f)));

  // Drag and drop: `dropSlot` is the slot under the pointer (-1 = the card, null = not dragging files).
  const [dropSlot, setDropSlot] = useState(null);
  // A file dropped anywhere else would make the browser open it and lose the form.
  useEffect(() => {
    const block = (e) => {
      if ([...(e.dataTransfer?.types || [])].includes('Files')) e.preventDefault();
    };
    const end = () => setDropSlot(null);
    window.addEventListener('dragover', block);
    window.addEventListener('drop', block);
    window.addEventListener('dragend', end);
    return () => {
      window.removeEventListener('dragover', block);
      window.removeEventListener('drop', block);
      window.removeEventListener('dragend', end);
    };
  }, []);
  const hasFiles = (e) => [...(e.dataTransfer?.types || [])].includes('Files');
  const dropProps = (slot) => ({
    onDragOver: (e) => {
      if (!hasFiles(e)) return;
      e.preventDefault();
      e.stopPropagation();
      e.dataTransfer.dropEffect = 'copy';
      if (dropSlot !== slot) setDropSlot(slot);
    },
    onDragLeave: (e) => {
      if (!e.currentTarget.contains(e.relatedTarget)) setDropSlot((s) => (s === slot ? null : s));
    },
    onDrop: (e) => {
      if (!hasFiles(e)) return;
      e.preventDefault();
      e.stopPropagation();
      setDropSlot(null);
      addFiles(slot === -1 ? null : slot, e.dataTransfer.files);
    },
  });

  const chosen = files.filter(Boolean);
  // Newly chosen photos count as changes too, so they are not lost by an accidental back or link click.
  const dirty = snapshot(form) !== snapshot(initial) || chosen.length > 0;
  const { dialog: leaveDialog, allowLeave } = useUnsavedChanges(dirty);

  // Errors show after the first submit attempt and then update as the fields change.
  const [submitted, setSubmitted] = useState(false);
  const [serverErrors, setServerErrors] = useState({});
  const check = () => validate(productSchema(editing), { ...form, imageCount: chosen.length });
  const errors = submitted ? { ...serverErrors, ...check().errors } : {};

  const submit = async (e) => {
    e.preventDefault();
    setSubmitted(true);
    setServerErrors({});
    const { data: valid, errors: found } = check();
    if (!valid) {
      const first = Object.keys(found)[0];
      document.getElementById(first)?.focus();
      document.getElementById(first)?.scrollIntoView({ block: 'center', behavior: 'smooth' });
      return;
    }

    const data = new FormData();
    data.append('name', valid.name);
    data.append('description', valid.description);
    data.append('price', String(valid.price));
    data.append('category', valid.category);
    data.append('subCategory', valid.subCategory);
    SIZES.filter((s) => valid.sizes.includes(s)).forEach((s) => data.append('sizes', s));
    data.append('bestseller', String(form.bestseller));
    chosen.forEach((f) => data.append('images', f)); // when editing, sending images replaces all current ones

    setSaving(true);
    try {
      if (editing) await api.adminUpdateProduct(id, data);
      else await api.adminCreateProduct(data);
      toast.success(editing ? 'Product updated' : 'Product created');
      allowLeave();
      onSaved();
    } catch (err) {
      if (err.fieldErrors) setServerErrors(err.fieldErrors);
      toast.error(err.message);
    } finally {
      setSaving(false);
    }
  };

  // Closing with unsaved changes asks first (navigating to another page is covered by useUnsavedChanges).
  const [confirmClose, setConfirmClose] = useState(false);
  const requestClose = () => (dirty && !saving ? setConfirmClose(true) : !saving && onClose());

  useEffect(() => {
    const onKey = (e) => {
      // Escape inside an open dropdown only closes the dropdown.
      if (e.key !== 'Escape' || confirmClose || document.querySelector('[role="listbox"]')) return;
      requestClose();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  });

  const title = editing ? `Edit product #${id}` : 'Add product';

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/40" onClick={requestClose} />
      <form
        onSubmit={submit}
        noValidate
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="relative flex h-full w-full max-w-4xl flex-col bg-gray-50 shadow-2xl"
      >
        <div className="flex items-center justify-between gap-3 border-b bg-white px-5 py-3">
          <h2 className="text-lg font-medium">{title}</h2>
          <button type="button" onClick={requestClose} aria-label="Close" className="rounded p-1 text-2xl leading-none text-gray-500 hover:bg-gray-100 hover:text-black">
            ×
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-5">
          {loading && <Loading />}
          <ErrorText error={loadError} />
          {!loading && !loadError && (
            <>
      {Object.keys(errors).length > 0 && (
        <p role="alert" className="mb-4 rounded border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-700">
          Fix the highlighted fields before saving.
        </p>
      )}

      <div className="grid lg:grid-cols-3 gap-4">
        <Card className="p-5 lg:col-span-2 flex flex-col gap-4">
          <Field label="Name" name="name" error={errors.name}>
            <input {...errorProps('name', errors.name)} maxLength={200} value={form.name} onChange={set('name')} className={inputClass(errors.name)} placeholder="e.g. Men Slim Fit Denim Jacket" />
          </Field>
          <Field label="Description" name="description" error={errors.description}>
            <textarea {...errorProps('description', errors.description)} rows={5} value={form.description} onChange={set('description')} className={inputClass(errors.description)} placeholder="Describe the product" />
          </Field>
          <div className="grid sm:grid-cols-3 gap-4">
            <div>
              <span id="category-label" className="block text-sm text-gray-600 mb-1.5">Category</span>
              <Dropdown
                {...errorProps('category', errors.category)}
                aria-labelledby="category-label"
                value={form.category}
                // Sub-categories belong to a category, so picking another category clears the sub-category.
                onChange={(category) => setForm((f) => ({ ...f, category, subCategory: category === f.category ? f.subCategory : '' }))}
                options={categories.map((c) => [c.name, c.name])}
                placeholder="Choose a category"
                className={`h-[38px] ${errors.category ? 'border-red-400' : ''}`}
              />
              <FieldError name="category" error={errors.category} />
              <Link to="/admin/categories" className="mt-1 inline-block text-xs text-gray-500 hover:underline">Manage categories</Link>
            </div>
            <div>
              <span id="sub-category-label" className="block text-sm text-gray-600 mb-1.5">Sub category</span>
              <Dropdown
                {...errorProps('subCategory', errors.subCategory)}
                aria-labelledby="sub-category-label"
                value={form.subCategory}
                onChange={(subCategory) => setForm((f) => ({ ...f, subCategory }))}
                options={subCategories.map((s) => [s.name, s.name])}
                placeholder={!form.category ? 'Choose a category first' : subCategories.length ? 'Choose a sub-category' : 'No sub-categories yet'}
                disabled={!form.category || subCategories.length === 0}
                className={`h-[38px] ${errors.subCategory ? 'border-red-400' : ''}`}
              />
              <FieldError name="subCategory" error={errors.subCategory} />
              {categoryId && (
                <Link to={`/admin/categories?id=${categoryId}`} className="mt-1 inline-block text-xs text-gray-500 hover:underline">
                  {subCategories.length ? 'Manage sub-categories' : `Add sub-categories to ${form.category}`}
                </Link>
              )}
            </div>
            <Field label="Price ($)" name="price" error={errors.price}>
              <input {...errorProps('price', errors.price)} type="text" inputMode="decimal" value={form.price} onChange={set('price')} className={inputClass(errors.price)} placeholder="100" />
            </Field>
          </div>

          <div>
            <span id="sizes-label" className="block text-sm text-gray-600 mb-2">Sizes</span>
            <div id="sizes" tabIndex={-1} role="group" aria-labelledby="sizes-label" aria-describedby={errors.sizes ? 'sizes-error' : undefined} className="flex flex-wrap gap-2">
              {SIZES.map((s) => (
                <button type="button" key={s} onClick={() => toggleSize(s)} aria-pressed={form.sizes.includes(s)}
                  className={`w-12 py-2 rounded border text-sm ${form.sizes.includes(s) ? 'bg-black text-white border-black' : `bg-white text-gray-600 ${errors.sizes ? 'border-red-400' : 'border-gray-300'}`}`}>
                  {s}
                </button>
              ))}
            </div>
            <FieldError name="sizes" error={errors.sizes} />
          </div>

          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={form.bestseller} onChange={(e) => setForm((f) => ({ ...f, bestseller: e.target.checked }))} className="w-4 h-4" />
            Show in &ldquo;Best seller&rdquo;
          </label>
        </Card>

        <Card className={`p-5 h-fit transition-colors ${dropSlot === -1 ? 'border-black bg-gray-50' : errors.imageCount ? 'border-red-400' : ''}`}>
          <div {...dropProps(-1)}>
            <span className="block text-sm text-gray-600">Images (up to {MAX_IMAGES}, max 5 MB each)</span>
            <span className="block text-xs text-gray-400 mb-3">Click a box or drag images here. You can drop several at once.</span>
            <FieldError name="imageCount" error={errors.imageCount} />
            <div id="imageCount" tabIndex={-1} className="grid grid-cols-2 gap-3 mt-1">
              {files.map((file, i) => (
                <div key={i} className="relative" {...dropProps(i)}>
                  <label
                    className={`relative block aspect-square border-2 border-dashed rounded overflow-hidden cursor-pointer bg-gray-50 transition-colors ${
                      dropSlot === i ? 'border-black bg-gray-100' : 'border-gray-300 hover:border-black'
                    }`}
                  >
                    <img
                      src={previews[i] || (editing && chosen.length === 0 ? existing[i] : null) || assets.upload_area}
                      alt={`Image ${i + 1}`}
                      className={`w-full h-full ${previews[i] || (editing && chosen.length === 0 && existing[i]) ? 'object-cover' : 'object-contain p-6 opacity-60'}`}
                    />
                    {dropSlot === i && (
                      <span className="absolute inset-0 flex items-center justify-center bg-white/80 text-xs font-medium text-black">
                        {file ? 'Drop to replace' : 'Drop image here'}
                      </span>
                    )}
                    <input type="file" multiple accept={IMAGE_TYPES.join(',')} hidden onChange={(e) => { addFiles(i, e.target.files); e.target.value = ''; }} />
                  </label>
                  {file && (
                    <button type="button" onClick={() => clearFile(i)} aria-label={`Remove image ${i + 1}`}
                      className="absolute -top-2 -right-2 w-6 h-6 rounded-full bg-black text-white text-sm leading-6">×</button>
                  )}
                </div>
              ))}
            </div>
          </div>
          {editing && (
            <p className="text-xs text-gray-400 mt-3">
              {chosen.length === 0
                ? 'Showing the current images. Upload new ones to replace all of them.'
                : `The ${existing.length} current image${existing.length === 1 ? '' : 's'} will be replaced by ${chosen.length} new one${chosen.length === 1 ? '' : 's'}.`}
            </p>
          )}
        </Card>
      </div>
            </>
          )}
        </div>

        <div className="flex items-center justify-end gap-3 border-t bg-white px-5 py-3">
          <button type="button" onClick={requestClose} disabled={saving} className="rounded border border-gray-300 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50">
            Cancel
          </button>
          <button disabled={saving || loading || Boolean(loadError)} className="rounded bg-black px-5 py-2 text-sm text-white disabled:bg-gray-400">
            {saving ? 'Saving...' : editing ? 'Save changes' : 'Create product'}
          </button>
        </div>
      </form>
      {leaveDialog}
      {confirmClose && (
        <ConfirmDialog
          message="You have unsaved changes to this product. Close and discard them?"
          onCancel={() => setConfirmClose(false)}
          onConfirm={() => {
            setConfirmClose(false);
            allowLeave();
            onClose();
          }}
        />
      )}
    </div>
  );
};

export default ProductForm;
