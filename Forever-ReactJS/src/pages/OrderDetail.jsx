import { useContext } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api } from '../api/client';
import useApi from '../components/useApi';
import { ShopContext } from '../context/ShopContext';

const STEPS = [
  ['ORDER_PLACED', 'Placed'],
  ['SHIPPED', 'Shipped'],
  ['DELIVERED', 'Delivered'],
];

const OrderDetail = () => {
  const { orderId } = useParams();
  const { currency } = useContext(ShopContext);
  const { data: order, loading, error } = useApi(() => api.order(orderId), [orderId]);

  if (loading) return <p className="border-t py-16 text-gray-500">Loading order...</p>;
  if (error) return <div className="border-t py-16"><p className="text-red-500">{error.message}</p><Link to="/order" className="mt-4 inline-block underline">Back to orders</Link></div>;
  if (!order) return null;

  const currentStep = STEPS.findIndex(([status]) => status === order.status);
  const cancelled = order.status === 'CANCELLED';

  return (
    <div className="border-t py-14 text-gray-700">
      <Link to="/order" className="text-sm text-gray-500 hover:text-black">← Back to orders</Link>
      <div className="mt-5 flex flex-wrap items-end justify-between gap-3">
        <div><p className="text-sm uppercase tracking-wider text-gray-500">Order details</p><h1 className="text-3xl font-medium text-gray-900">Order #{order.id}</h1></div>
        <p className="text-sm">Placed {new Date(order.createdAt).toLocaleDateString(undefined, { day: 'numeric', month: 'long', year: 'numeric' })}</p>
      </div>

      <div className="my-9 rounded-lg border p-5 sm:p-7">
        {cancelled ? (
          <div>
            <p className="font-medium text-red-600">
              {order.cancelledBy === 'ADMIN' ? 'We cancelled this order.' : 'This order was cancelled.'}
            </p>
            {order.cancelReason && <p className="mt-2 text-sm text-gray-700">Reason: {order.cancelReason}</p>}
          </div>
        ) : (
          <div className="grid grid-cols-3 gap-2">
            {STEPS.map(([status, label], index) => (
              <div key={status} className="text-center">
                <div className={`mx-auto mb-2 h-2.5 w-2.5 rounded-full ${index <= currentStep ? 'bg-black' : 'bg-gray-200'}`} />
                <div className={`h-1 ${index <= currentStep ? 'bg-black' : 'bg-gray-200'}`} />
                <p className={`mt-2 text-[10px] sm:text-xs ${index === currentStep ? 'font-semibold text-black' : 'text-gray-500'}`}>{label}</p>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="grid gap-8 lg:grid-cols-[1fr_320px]">
        <div className="rounded-lg border">
          {order.items.map((item, index) => (
            <div key={`${item.productId}-${item.size}`} className={`flex gap-4 p-4 ${index ? 'border-t' : ''}`}>
              <img src={item.image} alt={item.name} className="h-24 w-20 object-cover" />
              <div className="flex-1"><p className="font-medium text-gray-900">{item.name}</p><p className="mt-2 text-sm text-gray-500">Size {item.size} · Quantity {item.quantity}</p></div>
              <p className="font-medium">{currency}{Number(item.price * item.quantity).toFixed(2)}</p>
            </div>
          ))}
        </div>
        <aside className="space-y-5">
          <div className="rounded-lg border p-5"><h2 className="mb-3 font-medium text-black">Delivery address</h2><p>{order.address.firstName} {order.address.lastName}</p><p>{order.address.street}</p><p>{order.address.city}, {order.address.state} {order.address.zipcode}</p><p>{order.address.country}</p><p className="mt-2 text-sm text-gray-500">{order.address.phone}</p></div>
          <div className="rounded-lg border p-5 text-sm"><h2 className="mb-3 text-base font-medium text-black">Summary</h2><p className="flex justify-between py-1"><span>Items</span><span>{currency}{Number(order.itemsAmount).toFixed(2)}</span></p>{Number(order.discount) > 0 && <p className="flex justify-between py-1 text-green-700"><span>Discount ({order.couponCode})</span><span>-{currency}{Number(order.discount).toFixed(2)}</span></p>}<p className="flex justify-between py-1"><span>{order.shippingMethod === 'EXPRESS' ? 'Express delivery' : 'Standard delivery'}</span><span>{currency}{Number(order.deliveryFee).toFixed(2)}</span></p><p className="mt-2 flex justify-between border-t pt-3 text-base font-medium text-black"><span>Total</span><span>{currency}{Number(order.total).toFixed(2)}</span></p><p className="mt-4 text-gray-500">Payment: {order.paymentMethod.replaceAll('_', ' ')}</p></div>
        </aside>
      </div>
    </div>
  );
};

export default OrderDetail;
