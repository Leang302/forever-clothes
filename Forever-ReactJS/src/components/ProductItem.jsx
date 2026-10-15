import { useContext } from 'react';
import { ShopContext } from '../context/ShopContext';
import { Link } from 'react-router-dom';

const ProductItem = ({ id, image, name, price }) => {
   const { currency, wishlist, toggleWishlist, isAdmin } = useContext(ShopContext);
   const saved = wishlist.some((item) => item.id === id);
   const product = { id, images: image, name, price };

   return (
      <div className='relative text-gray-700'>
         {!isAdmin && (
            <button type="button" aria-label={saved ? 'Remove from wishlist' : 'Add to wishlist'}
               onClick={() => toggleWishlist(product)}
               className={`absolute right-2 top-2 z-10 flex h-9 w-9 items-center justify-center rounded-full bg-white/90 text-xl shadow ${saved ? 'text-red-500' : 'text-gray-500'}`}>
               {saved ? '♥' : '♡'}
            </button>
         )}
         <Link to={`/product/${id}`} className='cursor-pointer'>
         <div className="overflow-hidden rounded">
            <img className='hover:scale-110 transition ease-in-out' src={image[0]} alt={name} />       
         </div>
         <p className='pt-3 pb-1 text-sm'>{name}</p>
         <p className='text-sm font-medium'>{currency}{price}</p>
         </Link>
      </div>
   );
}

export default ProductItem;
