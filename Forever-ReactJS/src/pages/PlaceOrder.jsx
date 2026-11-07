//PlaceOrder.jsx
import { useCallback, useContext, useEffect, useRef, useState } from "react";
import { toast } from "react-toastify";
import { useSearchParams } from "react-router-dom";
import CartTotal from "../components/CartTotal";
import KhqrPayment from "../components/KhqrPayment";
import Title from "../components/Title";
import { ShopContext } from "../context/ShopContext";
import { api, orderAccess } from "../api/client";
import { email, text, validate, z } from "@/lib/validation";
import { lineProblem } from "../lib/stock";

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

// crypto.randomUUID only exists in secure contexts (https / localhost); a plain-http LAN deployment still
// needs a key, so fall back to 128 random bits.
const newIdempotencyKey = () => {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
};

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
  const [paymentMethod, setPaymentMethod] = useState('COD');
  // The pending KHQR order whose code is on screen.
  const [khqrPayment, setKhqrPayment] = useState(null);
  const [addresses, setAddresses] = useState([]);
  const [selectedAddressId, setSelectedAddressId] = useState(null);
  const [saveAddress, setSaveAddress] = useState(false);
  const [addressLabel, setAddressLabel] = useState('Home');
  // Not logged in = guest checkout: an EMPTY form (never prefilled with made-up data), no saved addresses.
  const isGuest = !user;
  const [first, ...rest] = (user?.name || '').split(' ');
  const [form, setForm] = useState({
    firstName: first || '', lastName: rest.join(' '), email: user?.email || '', street: '',
    city: '', state: '', zipcode: '', country: '', phone: user?.phone || '',
  });
  const formRef = useRef(null);
  // Idempotency key policy: one key per set of checkout details. Retrying the SAME details (timeout, double
  // submit, retry after an error) resends the same key, so the server returns the original order / the same
  // KHQR code instead of creating a duplicate. If the shopper changes any detail after an attempt, a NEW
  // key is used (reusing the old one would be rejected with 409 IDEMPOTENCY_KEY_MISMATCH). After a KHQR
  // order is cancelled/expired the key is retired too, since replaying it would hit that cancelled order.
  const attemptRef = useRef(null);
  if (attemptRef.current === null) attemptRef.current = { key: newIdempotencyKey(), fingerprint: null };
  const keyFor = (fingerprint) => {
    const attempt = attemptRef.current;
    if (attempt.fingerprint !== null && attempt.fingerprint !== fingerprint) {
      attemptRef.current = { key: newIdempotencyKey(), fingerprint };
    } else {
      attempt.fingerprint = fingerprint;
    }
    return attemptRef.current.key;
  };
  const retireKey = () => { attemptRef.current = { key: newIdempotencyKey(), fingerprint: null }; };
  // Guards against a second submit before React has re-rendered the disabled button.
  const submitting = useRef(false);
  // Last order error, shown next to the submit button (in addition to the toast).
  const [orderError, setOrderError] = useState(null);
  const blockedItems = checkoutItems.filter((item) => lineProblem(item));
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
    // Saved addresses are an account feature; a guest only needs the checkout options.
    Promise.all([isGuest ? [] : api.addresses(), api.checkoutOptions()]).then(([saved, options]) => {
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
  }, [loadCart, isGuest]);

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
    if (blockedItems.length) {
      setOrderError('Some items have less stock than the quantity you picked. Go back to your cart to adjust them.');
      return;
    }
    if (submitting.current) return;
    submitting.current = true;
    setBusy(true);
    setOrderError(null);
    try {
      if (saveAddress) {
        const saved = await api.addAddress({ label: addressLabel, ...form });
        setAddresses((items) => [saved, ...items.filter((item) => item.id !== saved.id)]);
        setSelectedAddressId(saved.id);
        setSaveAddress(false);
      }
      const details = { address: form, paymentMethod, shippingMethod, couponCode: couponCode.trim() || null, cartItemIds: pickedIds.length ? checkoutItems.map((item) => item.id) : null };
      const request = { ...details, idempotencyKey: keyFor(JSON.stringify(details)) };
      if (paymentMethod === 'KHQR') {
        const payment = await api.khqrCheckout(request);
        // Guest order: its access token (for polling / cancelling / the confirmation) stays in this tab only.
        orderAccess.set(payment.orderId, payment.guestAccessToken);
        setKhqrPayment(payment);
        await loadCart(); // the order took its lines out of the cart; cancelling puts them back
        return;
      }
      const order = await api.placeOrder(request);
      orderAccess.set(order.id, order.guestAccessToken);
      await loadCart();
      toast.success('Order placed — pay on delivery');
      navigate(`/order-confirmation/${order.id}`);
    } catch (e) {
      let message = e.message;
      if (e.code === 'IDEMPOTENCY_KEY_MISMATCH') {
        // Shouldn't happen with keyFor(), but if it does the old key is unusable: start a fresh attempt.
        retireKey();
        message = 'Your checkout details changed since your last attempt. Please check them and place the order again.';
      } else if (e.code === 'ORDER_ALREADY_PAID') {
        retireKey();
        message = isGuest
          ? 'This order has already been paid — no need to pay again. Check your email for the confirmation.'
          : 'This order has already been paid. You can find it under My orders — no need to pay again.';
      } else if (e.code === 'ORDER_NOT_PENDING') {
        retireKey();
        message = 'That payment attempt was cancelled. Press the button again to start a new one.';
      } else if (e.code === 'OUT_OF_STOCK') {
        loadCart(); // refresh the lines' stock so the problem shows on the cart
      }
      setOrderError(message);
      toast.error(message);
      if (e.fieldErrors) {
        setErrors(toFormErrors(e.fieldErrors));
        focusFirstError();
      }
    } finally {
      submitting.current = false;
      setBusy(false);
    }
  };

  // Only called by KhqrPayment after the API's verify endpoint reported paid = true.
  const onKhqrPaid = useCallback(() => {
    const orderId = khqrPayment.orderId;
    setKhqrPayment(null);
    toast.success('Payment received');
    navigate(`/order-confirmation/${orderId}`);
  }, [khqrPayment, navigate]);

  const onKhqrClosed = useCallback((reason) => {
    setKhqrPayment(null);
    // The cancelled/expired order owns the old key; a new attempt needs a new one.
    attemptRef.current = { key: newIdempotencyKey(), fingerprint: null };
    loadCart();
    toast.info(reason === 'expired'
      ? 'The KHQR code expired. Your items are back in your cart'
      : 'Payment cancelled. Your items are back in your cart');
  }, [loadCart]);

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
        {!isGuest && (
          <label className="mt-2 flex items-center gap-2 text-sm text-gray-600">
            <input type="checkbox" checked={saveAddress} onChange={(e) => {
              setSaveAddress(e.target.checked);
              if (e.target.checked) setSelectedAddressId(null);
              revalidate(form, e.target.checked);
            }} />
            Save this address for next time
          </label>
        )}
        {!isGuest && saveAddress && (
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
            {[
              ['COD', 'Cash on Delivery', 'Pay when your order arrives'],
              ['KHQR', 'KHQR', 'Scan with Bakong or any Cambodian banking app'],
            ].map(([value, name, hint]) => (
              <button type="button" key={value} onClick={() => setPaymentMethod(value)} aria-pressed={paymentMethod === value}
                className={`flex items-center gap-3 rounded border p-3 text-left ${paymentMethod === value ? 'border-black bg-gray-50' : ''}`}>
                <p className={`min-w-3.5 h-3.5 border rounded-full ${paymentMethod === value ? 'bg-green-500' : ''}`}></p>
                <span><b className="text-sm">{name}</b><small className="block text-gray-500">{hint}</small></span>
              </button>
            ))}
          </div>
          {blockedItems.length > 0 && (
            <p role="alert" className="mt-6 max-w-sm text-sm text-red-600">
              {blockedItems.map((item) => `${item.name}: ${lineProblem(item)}`).join(' ')}{' '}
              <button type="button" onClick={() => navigate('/cart')} className="underline">Back to cart</button>
            </p>
          )}
          {orderError && (
            <p role="alert" data-testid="order-error" className="mt-6 max-w-sm text-sm text-red-600">{orderError}</p>
          )}
          <div className="w-full text-end mt-8 ">
            <button type="submit" disabled={busy || checkoutItems.length === 0 || blockedItems.length > 0} className="uppercase text-sm bg-black text-white px-16 py-5 rounded disabled:bg-gray-400">
              {busy ? 'Processing...' : paymentMethod === 'KHQR' ? 'Pay with KHQR' : 'Place order'}
            </button>
          </div>
        </div>
      </div>
      {khqrPayment && <KhqrPayment payment={khqrPayment} accessToken={khqrPayment.guestAccessToken} onPaid={onKhqrPaid} onClosed={onKhqrClosed} />}
    </form>
  );
};

export default PlaceOrder;
