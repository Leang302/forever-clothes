import ProductItem from "./ProductItem";

// Shared product grid with loading / error / empty states. `refreshing` keeps the current products on
// screen (dimmed) while new results load, instead of replacing them with "Loading...".
// `hideEmptyMessage` lets a page (e.g. Collection) show its own richer empty state instead of this one.
const ProductGridSection = ({ products, loading, error, refreshing = false, cols = "grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5", hideEmptyMessage = false }) => {
  if (loading) return <p className="text-center text-gray-400 py-10">Loading...</p>;
  if (error) return <p className="text-center text-red-500 py-10">{error.message}</p>;
  if (!hideEmptyMessage && products.length === 0) {
    return <p className="text-center text-gray-500 py-10">No products found.</p>;
  }
  return (
    <div className={`grid ${cols} gap-4 gap-y-6 transition-opacity ${refreshing ? 'opacity-50 pointer-events-none' : ''}`} aria-busy={refreshing}>
      {products.map((item) => (
        <ProductItem key={item.id} product={item} />
      ))}
    </div>
  );
};

export default ProductGridSection;
