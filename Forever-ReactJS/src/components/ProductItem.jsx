import { useContext, useEffect, useRef, useState } from 'react';
import { ShopContext } from '../context/ShopContext';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import { buyableSizes, clampQty, maxQty, sizeStock } from '../lib/stock';

// Product card used on Home / Collection / Related / Wishlist. Besides linking to the detail page it has an
// "Add to Cart" button that opens a small size + quantity panel (only in-stock sizes are selectable).
// The panel's open state starts closed on both server and client, so SSR hydration sees identical markup;
// it only opens after a click.
const ProductItem = ({ product: initialProduct }) => {
   const { currency, wishlist, toggleWishlist, isAdmin, addToCart } = useContext(ShopContext);
   // Local copy so a 409 OUT_OF_STOCK can refresh this card's stock without reloading the whole grid.
   const [product, setProduct] = useState(initialProduct);
   useEffect(() => setProduct(initialProduct), [initialProduct]);
   const { id, images: image = [], name, price, description } = product;
   const saved = wishlist.some((item) => item.id === id);
   const inStock = Boolean(product.inStock);

   const [open, setOpen] = useState(false);
   const [size, setSize] = useState('');
   const [quantity, setQuantity] = useState(1);
   const [adding, setAdding] = useState(false);
   const panelRef = useRef(null);

   const openPanel = () => {
      const sizes = buyableSizes(product);
      // Exactly one size left in stock: preselect it so the shopper only confirms.
      setSize(sizes.length === 1 ? sizes[0] : '');
      setQuantity(1);
      setOpen(true);
   };

   // Close on Escape or a click outside the panel.
   useEffect(() => {
      if (!open) return undefined;
      const onKey = (e) => e.key === 'Escape' && setOpen(false);
      const onDown = (e) => panelRef.current && !panelRef.current.contains(e.target) && setOpen(false);
      document.addEventListener('keydown', onKey);
      document.addEventListener('mousedown', onDown);
      return () => {
         document.removeEventListener('keydown', onKey);
         document.removeEventListener('mousedown', onDown);
      };
   }, [open]);

   const sizeMax = size ? maxQty(product, size) : 1;

   const confirm = async () => {
      setAdding(true);
      try {
         const result = await addToCart(id, size, quantity);
         if (result?.ok) setOpen(false);
         else if (result?.error?.code === 'OUT_OF_STOCK') {
            try {
               const fresh = await api.product(id);
               setProduct(fresh);
               if (size) setQuantity((q) => clampQty(q, maxQty(fresh, size)));
               if (size && sizeStock(fresh, size) === 0) setSize('');
            } catch { /* keep the card as is */ }
         }
      } finally {
         setAdding(false);
      }
   };

   return (
      <div className='relative text-gray-700' data-testid="product-card" data-product-id={id}>
         {!isAdmin && (
            <button type="button" aria-label={saved ? 'Remove from wishlist' : 'Add to wishlist'}
               onClick={() => toggleWishlist(product)}
               className={`absolute right-2 top-2 z-10 flex h-9 w-9 items-center justify-center rounded-full bg-white/90 text-xl shadow ${saved ? 'text-red-500' : 'text-gray-500'}`}>
               {saved ? '♥' : '♡'}
            </button>
         )}
         <Link to={`/product/${id}`} className='cursor-pointer'>
         <div className="relative overflow-hidden rounded">
            <img className={`hover:scale-110 transition ease-in-out ${inStock ? '' : 'opacity-60'}`} src={image[0]} alt={name} />
            {!inStock && (
               <span className="absolute left-2 top-2 rounded bg-black/80 px-2 py-0.5 text-xs text-white">Out of stock</span>
            )}
         </div>
         <p className='pt-3 pb-1 text-sm'>{name}</p>
         {description && <p className='line-clamp-2 text-xs text-gray-500'>{description}</p>}
         <p className='pt-1 text-sm font-medium'>{currency}{price}</p>
         </Link>
         {!isAdmin && (
            <button type="button" onClick={openPanel} disabled={!inStock} aria-expanded={open} aria-haspopup="dialog"
               aria-label={inStock ? `Add ${name} to cart` : `${name} is out of stock`}
               className="mt-2 w-full border border-black py-1.5 text-xs uppercase tracking-wide hover:bg-black hover:text-white disabled:cursor-not-allowed disabled:border-gray-300 disabled:text-gray-400 disabled:hover:bg-transparent">
               {inStock ? 'Add to Cart' : 'Out of stock'}
            </button>
         )}
         {open && (
            <div ref={panelRef} role="dialog" aria-label={`Add ${name} to cart`}
               className="absolute inset-x-0 bottom-0 z-20 rounded border border-gray-300 bg-white p-3 text-sm shadow-lg">
               <div className="mb-2 flex items-center justify-between">
                  <p className="font-medium">Choose size</p>
                  <button type="button" onClick={() => setOpen(false)} aria-label="Close" className="px-1 text-lg leading-none text-gray-500 hover:text-black">×</button>
               </div>
               <div className="flex flex-wrap gap-1.5">
                  {product.sizes.map((s) => {
                     const left = sizeStock(product, s);
                     return (
                        <button key={s} type="button" disabled={left === 0} aria-pressed={s === size}
                           aria-label={left === 0 ? `Size ${s} (out of stock)` : `Size ${s}`}
                           title={left === 0 ? 'Out of stock' : left <= 5 ? `Only ${left} left` : undefined}
                           onClick={() => { setSize(s); setQuantity((q) => clampQty(q, maxQty(product, s))); }}
                           className={`min-w-9 rounded border px-2 py-1 text-xs ${s === size ? 'border-black bg-black text-white' : 'border-gray-300'} ${left === 0 ? 'cursor-not-allowed opacity-40 line-through' : ''}`}>
                           {s}
                        </button>
                     );
                  })}
               </div>
               {size && sizeStock(product, size) <= 5 && (
                  <p className="mt-1 text-xs text-amber-600">Only {sizeStock(product, size)} left in size {size}</p>
               )}
               <div className="mt-2 flex items-center gap-1.5">
                  <span className="mr-1 text-xs text-gray-500">Qty</span>
                  <button type="button" aria-label="Decrease quantity" disabled={quantity <= 1} onClick={() => setQuantity((q) => Math.max(1, q - 1))}
                     className="h-7 w-7 rounded border disabled:opacity-40">−</button>
                  <input type="number" aria-label="Quantity" min={1} max={sizeMax} value={quantity}
                     onChange={(e) => e.target.value !== '' && setQuantity(clampQty(e.target.value, size ? sizeMax : 1))}
                     className="h-7 w-10 rounded border text-center [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none" />
                  <button type="button" aria-label="Increase quantity" disabled={!size || quantity >= sizeMax} onClick={() => setQuantity((q) => clampQty(q + 1, sizeMax))}
                     className="h-7 w-7 rounded border disabled:opacity-40">+</button>
               </div>
               <button type="button" onClick={confirm} disabled={!size || adding}
                  className="mt-3 w-full bg-black py-2 text-xs uppercase text-white disabled:bg-gray-400">
                  {adding ? 'Adding...' : size ? 'Add to cart' : 'Select a size'}
               </button>
            </div>
         )}
      </div>
   );
}

export default ProductItem;
