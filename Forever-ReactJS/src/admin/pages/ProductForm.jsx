import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { toast } from "react-toastify";
import { api } from "../../api/client";
import { assets } from "../../assets/admin_assets/assets";
import { Card, ErrorText, Loading, PageTitle } from "../components/ui";

const SIZES = ['S', 'M', 'L', 'XL', 'XXL'];
const MAX_IMAGES = 4;
const MAX_BYTES = 5 * 1024 * 1024;

const empty = { name: '', description: '', price: '', category: '', subCategory: '', sizes: [], bestseller: false };

const inputClass = "w-full border border-gray-300 rounded px-3 py-2 text-sm bg-white focus:outline-none focus:border-black";

const Field = ({ label, children, hint }) => (
  <label className="block">
    <span className="block text-sm text-gray-600 mb-1.5">{label}</span>
    {children}
    {hint && <span className="block text-xs text-gray-400 mt-1">{hint}</span>}
  </label>
);

const ProductForm = () => {
  const { id } = useParams();
  const editing = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState(empty);
  const [files, setFiles] = useState(Array(MAX_IMAGES).fill(null)); // new uploads per slot
  const [existing, setExisting] = useState([]); // current image URLs when editing
  const [options, setOptions] = useState({ categories: [], subCategories: [] });
  const [loading, setLoading] = useState(editing);
  const [loadError, setLoadError] = useState(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    Promise.all([api.filters(), api.adminCategories()]).then(([filters, managed]) => setOptions({
      ...filters,
      categories: [...new Set([...managed.filter((c) => c.active).map((c) => c.name), ...filters.categories])],
    })).catch(() => {});
  }, []);

  useEffect(() => {
    if (!editing) return;
    api.adminProduct(id)
      .then((p) => {
        setForm({
          name: p.name, description: p.description, price: String(p.price), category: p.category,
          subCategory: p.subCategory, sizes: p.sizes, bestseller: p.bestseller,
        });
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

  const pickFile = (slot, file) => {
    if (!file) return;
    if (!file.type.startsWith('image/')) return toast.error('Please choose an image file');
    if (file.size > MAX_BYTES) return toast.error('Each image must be 5 MB or smaller');
    setFiles((prev) => prev.map((f, i) => (i === slot ? file : f)));
  };
  const clearFile = (slot) => setFiles((prev) => prev.map((f, i) => (i === slot ? null : f)));

  const chosen = files.filter(Boolean);

  const submit = async (e) => {
    e.preventDefault();
    if (form.sizes.length === 0) return toast.error('Select at least one size');
    if (!editing && chosen.length === 0) return toast.error('Upload at least one image');
    if (Number(form.price) <= 0) return toast.error('Price must be greater than zero');

    const data = new FormData();
    data.append('name', form.name.trim());
    data.append('description', form.description.trim());
    data.append('price', form.price);
    data.append('category', form.category.trim());
    data.append('subCategory', form.subCategory.trim());
    SIZES.filter((s) => form.sizes.includes(s)).forEach((s) => data.append('sizes', s));
    data.append('bestseller', String(form.bestseller));
    chosen.forEach((f) => data.append('images', f)); // when editing, sending images replaces all current ones

    setSaving(true);
    try {
      if (editing) await api.adminUpdateProduct(id, data);
      else await api.adminCreateProduct(data);
      toast.success(editing ? 'Product updated' : 'Product created');
      navigate('/admin/products');
    } catch (err) {
      toast.error(err.message);
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <Loading />;
  if (loadError) return <ErrorText error={loadError} />;

  return (
    <form onSubmit={submit}>
      <PageTitle title={editing ? `Edit product #${id}` : 'Add product'}>
        <Link to="/admin/products" className="text-sm text-gray-500 hover:text-black">Cancel</Link>
        <button disabled={saving} className="bg-black text-white text-sm px-5 py-2 rounded disabled:bg-gray-400">
          {saving ? 'Saving...' : editing ? 'Save changes' : 'Create product'}
        </button>
      </PageTitle>

      <div className="grid lg:grid-cols-3 gap-4">
        <Card className="p-5 lg:col-span-2 flex flex-col gap-4">
          <Field label="Name">
            <input required maxLength={200} value={form.name} onChange={set('name')} className={inputClass} placeholder="e.g. Men Slim Fit Denim Jacket" />
          </Field>
          <Field label="Description">
            <textarea required rows={5} value={form.description} onChange={set('description')} className={inputClass} placeholder="Describe the product" />
          </Field>
          <div className="grid sm:grid-cols-3 gap-4">
            <Field label="Category">
              <input required list="categories" maxLength={40} value={form.category} onChange={set('category')} className={inputClass} placeholder="Men" />
              <datalist id="categories">{options.categories.map((c) => <option key={c} value={c} />)}</datalist>
            </Field>
            <Field label="Type">
              <input required list="subcategories" maxLength={40} value={form.subCategory} onChange={set('subCategory')} className={inputClass} placeholder="Topwear" />
              <datalist id="subcategories">{options.subCategories.map((c) => <option key={c} value={c} />)}</datalist>
            </Field>
            <Field label="Price ($)">
              <input required type="number" min="0.01" step="0.01" value={form.price} onChange={set('price')} className={inputClass} placeholder="100" />
            </Field>
          </div>

          <div>
            <span className="block text-sm text-gray-600 mb-2">Sizes</span>
            <div className="flex flex-wrap gap-2">
              {SIZES.map((s) => (
                <button type="button" key={s} onClick={() => toggleSize(s)} aria-pressed={form.sizes.includes(s)}
                  className={`w-12 py-2 rounded border text-sm ${form.sizes.includes(s) ? 'bg-black text-white border-black' : 'bg-white border-gray-300 text-gray-600'}`}>
                  {s}
                </button>
              ))}
            </div>
          </div>

          <label className="flex items-center gap-2 text-sm">
            <input type="checkbox" checked={form.bestseller} onChange={(e) => setForm((f) => ({ ...f, bestseller: e.target.checked }))} className="w-4 h-4" />
            Show in &ldquo;Best seller&rdquo;
          </label>
        </Card>

        <Card className="p-5 h-fit">
          <span className="block text-sm text-gray-600 mb-3">Images (up to {MAX_IMAGES}, max 5 MB each)</span>
          <div className="grid grid-cols-2 gap-3">
            {files.map((file, i) => (
              <div key={i} className="relative">
                <label className="block aspect-square border border-dashed border-gray-300 rounded overflow-hidden cursor-pointer bg-gray-50 hover:border-black">
                  <img
                    src={previews[i] || (editing && chosen.length === 0 ? existing[i] : null) || assets.upload_area}
                    alt={`Image ${i + 1}`}
                    className={`w-full h-full ${previews[i] || (editing && chosen.length === 0 && existing[i]) ? 'object-cover' : 'object-contain p-6 opacity-60'}`}
                  />
                  <input type="file" accept="image/*" hidden onChange={(e) => { pickFile(i, e.target.files[0]); e.target.value = ''; }} />
                </label>
                {file && (
                  <button type="button" onClick={() => clearFile(i)} aria-label={`Remove image ${i + 1}`}
                    className="absolute -top-2 -right-2 w-6 h-6 rounded-full bg-black text-white text-sm leading-6">×</button>
                )}
              </div>
            ))}
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
    </form>
  );
};

export default ProductForm;
