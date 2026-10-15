//PlaceOrder.jsx
import { useContext, useEffect, useRef, useState } from "react";
import { toast } from "react-toastify";
import CartTotal from "../components/CartTotal";
import Title from "../components/Title";
import { ShopContext } from "../context/ShopContext";
import { api } from "../api/client";

const inputClass = "border border-gray-300 rounded py-1.5 px-3.5 w-full";
const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

const PlaceOrder = () => {
  const { navigate, user, cart, loadCart } = useContext(ShopContext);
  const [method, setMethod] = useState("cod");
  const [shippingMethod, setShippingMethod] = useState('STANDARD');
  const [shippingOptions, setShippingOptions] = useState([]);
  const [couponCode, setCouponCode] = useState('');
  // Result of checking the coupon against the cart: { ok, text } shown under the input.
  const [couponCheck, setCouponCheck] = useState(null);
  const [busy, setBusy] = useState(false);
  const [paywayPayment, setPaywayPayment] = useState(null);
  const paymentCancelled = useRef(false);
  const [addresses, setAddresses] = useState([]);
  const [selectedAddressId, setSelectedAddressId] = useState(null);
  const [saveAddress, setSaveAddress] = useState(false);
  const [addressLabel, setAddressLabel] = useState('Home');
  const [first, ...rest] = (user?.name || '').split(' ');
  const [form, setForm] = useState({
    firstName: first || '', lastName: rest.join(' '), email: user?.email || '', street: '',
    city: '', state: '', zipcode: '', country: '', phone: user?.phone || '',
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
    setForm((f) => ({ ...f, [e.target.name]: e.target.value }));
  };

  const onSubmit = async (event) => {
    event.preventDefault();
    if (cart.items.length === 0) return toast.error('Your cart is empty');
    setBusy(true);
    paymentCancelled.current = false;
    let paywayCheckout = null;
    try {
      if (saveAddress) {
        const saved = await api.addAddress({ label: addressLabel, ...form });
        setAddresses((items) => [saved, ...items.filter((item) => item.id !== saved.id)]);
        setSelectedAddressId(saved.id);
        setSaveAddress(false);
      }
      const request = { address: form, paymentMethod: method === 'payway' ? 'PAYWAY' : 'COD', shippingMethod, couponCode: couponCode.trim() || null };
      if (method === 'payway') {
        const checkout = await api.paywayCheckout(request);
        paywayCheckout = checkout;
        setPaywayPayment(checkout);
        await loadCart();

        // The callback cannot reach localhost, so verify with PayWay from our backend.
        for (let attempt = 0; attempt < 100; attempt += 1) {
          await wait(3000);
          if (paymentCancelled.current) return;
          const result = await api.verifyPayway(checkout.orderId, checkout.transactionId);
          if (result.paid) {
            paywayCheckout = null;
            setPaywayPayment(null);
            toast.success('Payment confirmed');
            navigate(`/order-confirmation/${checkout.orderId}`);
            return;
          }
          if (['DECLINED', 'CANCELLED', 'FAILED'].includes(result.status?.toUpperCase())) {
            throw new Error(`ABA payment ${result.status.toLowerCase()}`);
          }
        }
        throw new Error('ABA payment timed out. Please try again.');
      }
      const order = await api.placeOrder(request);
      await loadCart();
      toast.success('Order placed successfully');
      navigate(`/order-confirmation/${order.id}`);
    } catch (e) {
      if (paywayCheckout) {
        try {
          await api.abortPayway(paywayCheckout.orderId);
          await loadCart();
        } catch {
          // If PayWay approved between checks, the backend refuses to restore the paid order.
        }
      }
      setPaywayPayment(null);
      toast.error(e.message);
    } finally {
      setBusy(false);
    }
  };

  const applyCoupon = async () => {
    const code = couponCode.trim();
    if (!code) return;
    try {
      const result = await api.checkCoupon(code, cart.subtotal);
      setCouponCheck({ ok: true, text: `${result.summary} — you save $${Number(result.discount).toFixed(2)}` });
    } catch (e) {
      setCouponCheck({ ok: false, text: e.message });
    }
  };

  const field = (name, placeholder, type = 'text') => (
    <input name={name} value={form[name]} onChange={onChange} className={inputClass} type={type} placeholder={placeholder} required />
  );

  const cancelPaywayPayment = async () => {
    if (!paywayPayment) return;
    paymentCancelled.current = true;
    try {
      await api.abortPayway(paywayPayment.orderId);
      await loadCart();
      toast.info('ABA payment cancelled');
    } catch (error) {
      toast.error(error.message);
    } finally {
      setPaywayPayment(null);
      setBusy(false);
    }
  };

  return (
    <form onSubmit={onSubmit} className="flex flex-col sm:flex-row justify-between gap-4 pt-5 sm:pt-14 min-h-[80vh] border-t">
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
                  setForm({ firstName: address.firstName, lastName: address.lastName, email: address.email,
                    street: address.street, city: address.city, state: address.state, zipcode: address.zipcode,
                    country: address.country, phone: address.phone });
                  setSelectedAddressId(address.id);
                  setSaveAddress(false);
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
          }} />
          Save this address for next time
        </label>
        {saveAddress && <input value={addressLabel} onChange={(e) => setAddressLabel(e.target.value)} className={inputClass} maxLength={50} placeholder="Address label, e.g. Home" required />}
      </div>
      {/* Right Side */}
      <div className="mt-8">
        <div className="mt-8 min-w-80">
          <CartTotal />
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
            <button type="button" onClick={()=>setMethod('cod')} className={`flex items-center gap-3 rounded border p-3 text-left ${method === 'cod' ? 'border-black bg-gray-50' : ''}`}>
              <p className={`min-w-3.5 h-3.5 border rounded-full ${method === 'cod' ? 'bg-green-500' : ''}`}></p>
              <span><b className="text-sm">Cash on Delivery</b><small className="block text-gray-500">Pay when your order arrives</small></span>
            </button>
            <button type="button" onClick={()=>setMethod('payway')} className={`flex items-center gap-3 rounded border p-3 text-left ${method === 'payway' ? 'border-black bg-gray-50' : ''}`}>
              <p className={`min-w-3.5 h-3.5 border rounded-full ${method === 'payway' ? 'bg-blue-600' : ''}`}></p>
              <span><b className="text-sm text-blue-700">ABA PayWay</b><small className="block text-gray-500">Pay securely with ABA Mobile</small></span>
            </button>
          </div>
          <div className="w-full text-end mt-8 ">
            <button type="submit" disabled={busy || cart.items.length === 0} className="uppercase text-sm bg-black text-white px-16 py-5 rounded disabled:bg-gray-400">
              {busy ? 'Processing...' : method === 'payway' ? 'Continue to ABA PayWay' : 'Place order'}
            </button>
          </div>
        </div>
      </div>
      {paywayPayment && (
        <div className="fixed inset-0 z-[1000] flex items-center justify-center bg-black/60 px-4">
          <div role="dialog" aria-modal="true" aria-labelledby="payway-title" className="w-full max-w-sm rounded-2xl bg-white p-6 text-center shadow-2xl">
            <div className="flex items-center justify-between">
              <div className="text-left">
                <p className="text-xs font-semibold uppercase tracking-widest text-blue-700">ABA PayWay</p>
                <h2 id="payway-title" className="mt-1 text-xl font-semibold text-gray-900">Scan to pay</h2>
              </div>
              <button type="button" onClick={cancelPaywayPayment} className="h-9 w-9 rounded-full text-xl text-gray-500 hover:bg-gray-100" aria-label="Cancel payment">×</button>
            </div>
            <img src={paywayPayment.qrImage} alt="ABA PayWay payment QR code" className="mx-auto mt-5 h-64 w-64 object-contain" />
            <p className="mt-4 text-sm text-gray-600">Open ABA Mobile and scan this QR code.</p>
            <p className="mt-1 text-xs text-gray-400">Waiting for secure payment confirmation…</p>
            {paywayPayment.deeplink && (
              <a href={paywayPayment.deeplink} className="mt-5 block rounded-lg bg-blue-700 px-5 py-3 text-sm font-semibold text-white sm:hidden">Open ABA Mobile</a>
            )}
            <button type="button" onClick={cancelPaywayPayment} className="mt-3 w-full rounded-lg border px-5 py-3 text-sm font-medium text-gray-700 hover:bg-gray-50">Cancel payment</button>
          </div>
        </div>
      )}
    </form>
  );
};

export default PlaceOrder;
