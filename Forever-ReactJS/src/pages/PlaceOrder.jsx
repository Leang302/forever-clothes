//PlaceOrder.jsx
import { useContext, useEffect, useRef, useState } from "react";
import { toast } from "react-toastify";
import { useSearchParams } from "react-router-dom";
import CartTotal from "../components/CartTotal";
import Title from "../components/Title";
import { ShopContext } from "../context/ShopContext";
import { api } from "../api/client";
import { email, text, validate, z } from "@/lib/validation";

// Same rules as OrderDtos.AddressDto (order address) and CustomerDtos.AddressRequest (saved address label) on the API.
const addressSchema = z.object({
  firstName: text('First name', 80),
  lastName: text('Last name', 80),
  email,
  street: text('Street', 200),
  city: text('City', 100),
  state: text('State', 100),
  zipcode: text('Zipcode', 20),
  country: text('Country', 100),
  phone: text('Phone number', 40),
});
const addressWithLabelSchema = addressSchema.extend({ addressLabel: text('Address label', 50) });

// Maps API field errors ("address.city" from placing the order, "label" from saving the address) to form fields.
const toFormErrors = (fieldErrors) => Object.fromEntries(Object.entries(fieldErrors).map(([key, message]) => {
  const name = key.replace(/^address\./, '');
  return [name === 'label' ? 'addressLabel' : name, message];
}));

const inputClass = "border border-gray-300 rounded py-1.5 px-3.5 w-full";
const fieldClass = (invalid) => `border ${invalid ? 'border-red-500' : 'border-gray-300'} rounded py-1.5 px-3.5 w-full`;

const PlaceOrder = () => {
  const { navigate, user, cart, loadCart } = useContext(ShopContext);
  // `?items=1,2` = the cart lines picked on the cart page; without it the whole cart is checked out.
  const [searchParams] = useSearchParams();
  const pickedIds = (searchParams.get('items') || '').split(',').map(Number).filter(Boolean);
  const checkoutItems = pickedIds.length ? cart.items.filter((item) => pickedIds.includes(item.id)) : cart.items;
  const checkoutSubtotal = checkoutItems.reduce((sum, item) => sum + Number(item.price) * item.quantity, 0);
  const [shippingMethod, setShippingMethod] = useState('STANDARD');
  const [shippingOptions, setShippingOptions] = useState([]);
  const [couponCode, setCouponCode] = useState('');
  // Result of checking the coupon against the cart: { ok, text } shown under the input.
  const [couponCheck, setCouponCheck] = useState(null);
  const [busy, setBusy] = useState(false);
  const [addresses, setAddresses] = useState([]);
  const [selectedAddressId, setSelectedAddressId] = useState(null);
  const [saveAddress, setSaveAddress] = useState(false);
  const [addressLabel, setAddressLabel] = useState('Home');
  const [first, ...rest] = (user?.name || '').split(' ');
  const [form, setForm] = useState({
    firstName: first || '', lastName: rest.join(' '), email: user?.email || '', street: '',
    city: '', state: '', zipcode: '', country: '', phone: user?.phone || '',
  });
  const formRef = useRef(null);
  const [errors, setErrors] = useState({});
  // Errors only show (and update while typing) once the order has been submitted.
  const [submitted, setSubmitted] = useState(false);

  const checkAddress = (values, withLabel, label) =>
    validate(withLabel ? addressWithLabelSchema : addressSchema, { ...values, addressLabel: label });
  const revalidate = (values, withLabel = saveAddress, label = addressLabel) => {
    if (submitted) setErrors(checkAddress(values, withLabel, label).errors);
  };
  const focusFirstError = () => requestAnimationFrame(() => {
    const target = formRef.current?.querySelector('[aria-invalid="true"]');
    target?.scrollIntoView({ block: 'center', behavior: 'smooth' });
    target?.focus({ preventScroll: true });
  });

  useEffect(() => {
    loadCart();
    Promise.all([api.addresses(), api.checkoutOptions()]).then(([saved, options]) => {
      setAddresses(saved);
      setShippingOptions(options.shippingMethods);
      if (saved.length > 0) {
        const address = saved[0];
        setForm({ firstName: address.firstName, lastName: address.lastName, email: address.email,
          street: address.street, city: address.city, state: address.state, zipcode: address.zipcode,
          country: address.country, phone: address.phone });
        setSelectedAddressId(address.id);
      }
    }).catch(() => {});
  }, [loadCart]);

  const onChange = (e) => {
    setSelectedAddressId(null);
    const next = { ...form, [e.target.name]: e.target.value };
    setForm(next);
    revalidate(next);
  };

  const onSubmit = async (event) => {
    event.preventDefault();
    if (checkoutItems.length === 0) return toast.error(cart.items.length ? 'No items selected. Go back to your cart to pick some' : 'Your cart is empty');
    setSubmitted(true);
    const { data, errors: found } = checkAddress(form, saveAddress, addressLabel);
    setErrors(found);
    if (!data) {
      focusFirstError();
      return;
    }
    setBusy(true);
    try {
      if (saveAddress) {
        const saved = await api.addAddress({ label: addressLabel, ...form });
        setAddresses((items) => [saved, ...items.filter((item) => item.id !== saved.id)]);
        setSelectedAddressId(saved.id);
        setSaveAddress(false);
      }
      const request = { address: form, paymentMethod: 'COD', shippingMethod, couponCode: couponCode.trim() || null, cartItemIds: pickedIds.length ? checkoutItems.map((item) => item.id) : null };
      const order = await api.placeOrder(request);
      await loadCart();
      toast.success('Order placed successfully');
      navigate(`/order-confirmation/${order.id}`);
    } catch (e) {
      toast.error(e.message);
      if (e.fieldErrors) {
        setErrors(toFormErrors(e.fieldErrors));
        focusFirstError();
      }
    } finally {
      setBusy(false);
    }
  };

  const applyCoupon = async () => {
    const code = couponCode.trim();
    if (!code) return;
    try {
      const result = await api.checkCoupon(code, checkoutSubtotal);
      setCouponCheck({
        ok: true,
        text: `${result.summary} — you save $${Number(result.discount).toFixed(2)}`,
        code: result.code,
        discount: Number(result.discount),
        subtotal: checkoutSubtotal, // the discount is only valid for this subtotal
      });
    } catch (e) {
      setCouponCheck({ ok: false, text: e.message });
    }
  };

  // Props linking an input to its inline error message, plus the message itself.
  const errorProps = (name) => ({
    'aria-invalid': errors[name] ? true : undefined,
    'aria-describedby': errors[name] ? `checkout-${name}-error` : undefined,
  });
  const errorText = (name) => errors[name] && (
    <p id={`checkout-${name}-error`} className="mt-1 text-sm text-red-600">{errors[name]}</p>
  );

  const field = (name, placeholder, type = 'text') => (
    <div className="w-full">
      <input name={name} value={form[name]} onChange={onChange} className={fieldClass(errors[name])} type={type}
        placeholder={placeholder} {...errorProps(name)} />
      {errorText(name)}
    </div>
  );

  return (
    <form ref={formRef} noValidate onSubmit={onSubmit}className="flex flex-col sm:flex-row justify-between gap-4 pt-5 sm:pt-14 min-h-[80vh] border-t">
      {/* Left Side */}
      <div className="flex flex-col gap-4 w-full sm:max-w-[480px]">
        <div className="text-xl sm:text-2xl my-3">
          <Title text1={"Delivery"} text2={"INFORMATION"}/>
        </div>
        {addresses.length > 0 && (
          <div className="mb-2">
            <p className="mb-2 text-sm font-medium">Saved addresses</p>
            <div className="flex flex-wrap gap-2">
              {addresses.map((address) => (
                <button key={address.id} type="button" onClick={() => {
                  const picked = { firstName: address.firstName, lastName: address.lastName, email: address.email,
                    street: address.street, city: address.city, state: address.state, zipcode: address.zipcode,
                    country: address.country, phone: address.phone };
                  setForm(picked);
                  setSelectedAddressId(address.id);
                  setSaveAddress(false);
                  revalidate(picked, false);
                }} className={`min-w-36 rounded border px-4 py-3 text-left text-sm transition-colors ${selectedAddressId === address.id ? 'border-black bg-gray-100 ring-1 ring-black' : 'hover:border-gray-500'}`}>
                  <span className="flex items-center justify-between gap-3 font-medium">
                    {address.label}
                    {selectedAddressId === address.id && <span className="text-xs text-green-700">✓ Selected</span>}
                  </span>
                  <span className="mt-1 block text-xs text-gray-500">{address.firstName} {address.lastName}</span>
                  <span className="block text-xs text-gray-500">{address.street}, {address.city}</span>
                </button>
              ))}
            </div>
          </div>
        )}
        <div className="flex gap-3">
          {field('firstName', 'First name')}
          {field('lastName', 'Last name')}
        </div>
        {field('email', 'Email address', 'email')}
        {field('street', 'Street')}
        <div className="flex gap-3">
          {field('city', 'City')}
          {field('state', 'State')}
        </div>
        <div className="flex gap-3">
          {field('zipcode', 'Zipcode')}
          {field('country', 'Country')}
        </div>
        {field('phone', 'Phone number', 'tel')}
        <label className="mt-2 flex items-center gap-2 text-sm text-gray-600">
          <input type="checkbox" checked={saveAddress} onChange={(e) => {
            setSaveAddress(e.target.checked);
            if (e.target.checked) setSelectedAddressId(null);
            revalidate(form, e.target.checked);
          }} />
          Save this address for next time
        </label>
        {saveAddress && (
          <div className="w-full">
            <input value={addressLabel} onChange={(e) => { setAddressLabel(e.target.value); revalidate(form, saveAddress, e.target.value); }}
              className={fieldClass(errors.addressLabel)} maxLength={50} placeholder="Address label, e.g. Home" {...errorProps('addressLabel')} />
            {errorText('addressLabel')}
          </div>
        )}
      </div>
      {/* Right Side */}
      <div className="mt-8">
        <div className="mt-8 min-w-80">
          <CartTotal
            items={checkoutItems}
            deliveryFee={shippingOptions.find((o) => o.code === shippingMethod)?.fee}
            shippingLabel={shippingOptions.find((o) => o.code === shippingMethod)?.name}
            discount={couponCheck?.ok && couponCheck.subtotal === checkoutSubtotal ? couponCheck.discount : 0}
            couponCode={couponCheck?.ok ? couponCheck.code : null}
          />
        </div>
        <div className="mt-12">
          <Title text1={"shipping"} text2={'method'}/>
          <div className="mb-8 flex flex-col gap-2">
            {shippingOptions.map((option) => <button type="button" key={option.code} onClick={() => setShippingMethod(option.code)} className={`flex justify-between rounded border p-3 text-left text-sm ${shippingMethod === option.code ? 'border-black bg-gray-50' : ''}`}><span><b>{option.name}</b><small className="block text-gray-500">{option.estimate}</small></span><span>${Number(option.fee).toFixed(2)}</span></button>)}
          </div>
          <Title text1={"coupon"} text2={'code'}/>
          <div className="mb-8">
            <div className="flex gap-2">
              <input value={couponCode} onChange={(e) => { setCouponCode(e.target.value.toUpperCase()); setCouponCheck(null); }} className={inputClass} placeholder="Optional coupon code" maxLength={30} />
              <button type="button" onClick={applyCoupon} disabled={!couponCode.trim()} className="rounded border border-black px-4 text-sm disabled:border-gray-300 disabled:text-gray-400">Apply</button>
            </div>
            {couponCheck && (
              <p className={`mt-2 text-sm ${couponCheck.ok ? 'text-green-700' : 'text-red-600'}`}>{couponCheck.text}</p>
            )}
          </div>
          <Title text1={"payment"} text2={'method'}/>
          <div className="flex flex-col gap-3">
            <div className="flex items-center gap-3 rounded border border-black bg-gray-50 p-3 text-left">
              <p className="min-w-3.5 h-3.5 border rounded-full bg-green-500"></p>
              <span><b className="text-sm">Cash on Delivery</b><small className="block text-gray-500">Pay when your order arrives</small></span>
            </div>
          </div>
          <div className="w-full text-end mt-8 ">
            <button type="submit" disabled={busy || checkoutItems.length === 0} className="uppercase text-sm bg-black text-white px-16 py-5 rounded disabled:bg-gray-400">
              {busy ? 'Processing...' : 'Place order'}
            </button>
          </div>
        </div>
      </div>
    </form>
  );
};

export default PlaceOrder;
