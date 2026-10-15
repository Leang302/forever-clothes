// Formatting helpers and the order status list shared by the admin pages.
export const money = (v) => `$${Number(v ?? 0).toFixed(2)}`;

export const formatDate = (iso) =>
  new Date(iso).toLocaleString(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });

// [api value, label, badge classes]
export const STATUSES = [
  ['PAYMENT_PENDING', 'Awaiting payment', 'bg-gray-100 text-gray-700'],
  ['ORDER_PLACED', 'Order placed', 'bg-amber-100 text-amber-700'],
  ['PACKING', 'Packing', 'bg-orange-100 text-orange-700'],
  ['SHIPPED', 'Shipped', 'bg-blue-100 text-blue-700'],
  ['OUT_FOR_DELIVERY', 'Out for delivery', 'bg-indigo-100 text-indigo-700'],
  ['DELIVERED', 'Delivered', 'bg-green-100 text-green-700'],
  ['CANCELLED', 'Cancelled', 'bg-red-100 text-red-700'],
];
