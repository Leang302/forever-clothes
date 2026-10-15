import ProductItem from "./ProductItem";

// Shared product grid with loading / error states. `refreshing` keeps the current products on screen (dimmed)
// while new results load, instead of replacing them with "Loading...".
const ProductGridSection = ({ products, loading, error, refreshing = false, cols = "grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5" }) => {
  if (loading) return <p className="text-center text-gray-400 py-10">Loading...</p>;
  if (error) return <p className="text-center text-red-500 py-10">{error.message}</p>;
  return (
    <div className={`grid ${cols} gap-4 gap-y-6 transition-opacity ${refreshing ? 'opacity-50 pointer-events-none' : ''}`} aria-busy={refreshing}>
      {products.map((item) => (
        <ProductItem key={item.id} id={item.id} name={item.name} image={item.images} price={item.price} />
      ))}
    </div>
  );
};

export default ProductGridSection;
