import { useContext } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api, orderAccess } from '../api/client';
import useApi from '../components/useApi';
import { ShopContext } from '../context/ShopContext';

const money = (v) => `$${Number(v ?? 0).toFixed(2)}`;

// What the header says is derived ONLY from the order the API returns (paid / status / paymentMethod), so
// this page never claims a payment that the server hasn't confirmed.
const outcomeOf = (order) => {
  if (order.status === 'CANCELLED') {
    return { tone: 'red', icon: '×', kicker: 'Order cancelled', title: 'This order was cancelled',
      payment: order.paid ? 'Paid (refund pending)' : 'Not paid' };
  }
  if (order.paid) {
    return { tone: 'green', icon: '✓', kicker: 'Payment received', title: 'Thank you — your order is paid',
      payment: order.paymentMethod === 'KHQR' ? 'Paid (KHQR)' : 'Paid' };
  }
  if (order.paymentMethod === 'COD') {
    return { tone: 'green', icon: '✓', kicker: 'Order confirmed', title: 'Order placed — pay on delivery',
      payment: 'Cash on delivery — pay when your order arrives' };
  }
  return { tone: 'amber', icon: '…', kicker: 'Awaiting payment', title: 'Awaiting payment',
    payment: 'Awaiting payment (KHQR) — not received yet' };
};

const TONES = {
  green: 'bg-green-100 text-green-700',
  amber: 'bg-amber-100 text-amber-700',
  red: 'bg-red-100 text-red-700',
};

// A visitor who isn't logged in and has no access token for this order in THIS tab (e.g. another browser,
// a closed tab, the next person on a shared device): nothing is fetched, nothing about the order is shown.
const Unavailable = ({ orderId }) => (
  <div className="flex min-h-[50vh] flex-col items-center border-t py-16 text-center" data-testid="confirmation-unavailable">
    <h1 className="text-2xl font-medium">This confirmation is no longer available on this device</h1>
    <p className="mt-3 max-w-md text-gray-500">
      Please check your email for the confirmation of order #{orderId}.
    </p>
    <Link to="/collection" className="mt-8 border border-black px-6 py-3 text-sm">Continue shopping</Link>
  </div>
);

const OrderConfirmation = () => {
  const { orderId } = useParams();
  const { user } = useContext(ShopContext);
  // Logged in: the account's own order. Otherwise: a guest order opened with the access token this tab got
  // when placing it (sessionStorage), or nothing at all.
  const access = user ? null : orderAccess.get(orderId);
  const { data: order, loading, error } = useApi(
    () => (user ? api.order(orderId) : access ? api.guestOrder(orderId, access) : Promise.resolve(null)),
    [orderId, user, access],
  );
  if (!user && !access) return <Unavailable orderId={orderId} />;
  if (loading) return <p className="border-t py-20 text-center text-gray-500">Loading your order...</p>;
  // The guest access token expired (it is short-lived; the order itself is kept): same polite message.
  if (error && !user && error.status === 404) return <Unavailable orderId={orderId} />;
  if (error) return <p className="border-t py-20 text-center text-red-500">{error.message}</p>;
  const outcome = outcomeOf(order);
  const a = order.address;
  return (
    <div className="flex min-h-[65vh] flex-col items-center border-t py-12 text-center" data-testid="order-confirmation">
      <div className={`flex h-16 w-16 items-center justify-center rounded-full text-3xl ${TONES[outcome.tone]}`}>{outcome.icon}</div>
      <p className="mt-6 text-sm uppercase tracking-[0.25em] text-gray-500">{outcome.kicker}</p>
      <h1 className="mt-2 text-3xl font-medium" data-testid="confirmation-title">{outcome.title}</h1>
      <p className="mt-3 max-w-md text-gray-500">
        Order <b data-testid="confirmation-order-id">#{order.id}</b>.{' '}
        {user ? 'You can follow its progress from your orders page.' : `We'll send updates to ${a.email}.`}
      </p>

      <div className="mt-8 w-full max-w-2xl text-left text-sm">
        <dl className="grid grid-cols-[9rem_1fr] gap-y-1.5 rounded border p-4">
          <dt className="text-gray-500">Payment</dt>
          <dd data-testid="confirmation-payment"><span className={`rounded px-2 py-0.5 text-xs ${TONES[outcome.tone]}`}>{outcome.payment}</span></dd>
          <dt className="text-gray-500">Order status</dt>
          <dd data-testid="confirmation-status">{order.status.replace(/_/g, ' ').toLowerCase()}</dd>
          <dt className="text-gray-500">Customer</dt>
          <dd data-testid="confirmation-customer">{a.firstName} {a.lastName}</dd>
          <dt className="text-gray-500">Email</dt>
          <dd data-testid="confirmation-email">{a.email}</dd>
          <dt className="text-gray-500">Phone</dt>
          <dd data-testid="confirmation-phone">{a.phone}</dd>
          <dt className="text-gray-500">Deliver to</dt>
          <dd>{a.street}, {a.city}, {a.state} {a.zipcode}, {a.country}</dd>
        </dl>

        <div className="mt-6 overflow-x-auto">
          <table className="w-full" data-testid="confirmation-items">
            <thead className="border-b text-left text-gray-500">
              <tr>
                <th className="py-2 font-normal">Item</th>
                <th className="py-2 font-normal">Size</th>
                <th className="py-2 text-right font-normal">Qty</th>
                <th className="py-2 text-right font-normal">Unit price</th>
                <th className="py-2 text-right font-normal">Subtotal</th>
              </tr>
            </thead>
            <tbody>
              {order.items.map((item, idx) => (
                <tr key={idx} className="border-b">
                  <td className="py-2">
                    <span className="flex items-center gap-3">
                      <img src={item.image} alt="" className="h-12 w-10 rounded object-cover" />
                      {item.name}
                    </span>
                  </td>
                  <td className="py-2">{item.size}</td>
                  <td className="py-2 text-right">{item.quantity}</td>
                  <td className="py-2 text-right">{money(item.price)}</td>
                  <td className="py-2 text-right">{money(Number(item.price) * item.quantity)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="mt-3 ml-auto flex w-64 flex-col gap-1">
            <p className="flex justify-between"><span className="text-gray-500">Items</span>{money(order.itemsAmount)}</p>
            {Number(order.discount) > 0 && (
              <p className="flex justify-between text-green-700"><span>Discount{order.couponCode ? ` (${order.couponCode})` : ''}</span>−{money(order.discount)}</p>
            )}
            <p className="flex justify-between"><span className="text-gray-500">Shipping</span>{money(order.deliveryFee)}</p>
            <p className="flex justify-between border-t pt-1 text-base font-semibold"><span>Total</span><span data-testid="confirmation-total">{money(order.total)}</span></p>
          </div>
        </div>
      </div>

      <div className="mt-8 flex gap-3">{user && <Link to={`/order/${orderId}`} className="bg-black px-6 py-3 text-sm text-white">View order</Link>}<Link to="/collection" className="border border-black px-6 py-3 text-sm">Continue shopping</Link></div>
    </div>
  );
};

export default OrderConfirmation;
