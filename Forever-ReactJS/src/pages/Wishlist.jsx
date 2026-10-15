import { useContext } from 'react';
import Title from '../components/Title';
import ProductItem from '../components/ProductItem';
import { ShopContext } from '../context/ShopContext';

const Wishlist = () => {
  const { wishlist } = useContext(ShopContext);
  return (
    <div className="border-t py-14">
      <div className="mb-8 text-2xl"><Title text1="my" text2="Wishlist" /></div>
      {wishlist.length === 0 ? (
        <p className="py-16 text-center text-gray-500">Your wishlist is empty. Tap the heart on a product to save it.</p>
      ) : (
        <div className="grid grid-cols-2 gap-4 gap-y-8 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
          {wishlist.map((product) => <ProductItem key={product.id} id={product.id} image={product.images} name={product.name} price={product.price} />)}
        </div>
      )}
    </div>
  );
};

export default Wishlist;
