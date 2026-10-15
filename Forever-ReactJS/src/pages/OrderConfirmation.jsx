import { Link, useParams } from 'react-router-dom';
import { api } from '../api/client';
import useApi from '../components/useApi';

const OrderConfirmation = () => {
  const { orderId } = useParams();
  const { data: order, loading, error } = useApi(() => api.order(orderId), [orderId]);
  if (loading) return <p className="border-t py-20 text-center text-gray-500">Confirming your order...</p>;
  if (error) return <p className="border-t py-20 text-center text-red-500">{error.message}</p>;
  return (
    <div className="flex min-h-[65vh] flex-col items-center justify-center border-t text-center">
      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-green-100 text-3xl text-green-700">✓</div>
      <p className="mt-6 text-sm uppercase tracking-[0.25em] text-gray-500">Order confirmed</p>
      <h1 className="mt-2 text-3xl font-medium">Thank you for your order</h1>
      <p className="mt-3 max-w-md text-gray-500">Order #{order?.id} has been placed successfully. You can follow its progress from your orders page.</p>
      <div className="mt-8 flex gap-3"><Link to={`/order/${orderId}`} className="bg-black px-6 py-3 text-sm text-white">View order</Link><Link to="/collection" className="border border-black px-6 py-3 text-sm">Continue shopping</Link></div>
    </div>
  );
};

export default OrderConfirmation;
