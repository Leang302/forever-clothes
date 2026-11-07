//Product.jsx
/* eslint-disable react/no-unescaped-entities */
import { useContext, useEffect, useRef, useState } from "react";
import { useParams } from "react-router-dom"
import { ShopContext } from "../context/ShopContext";
import { api } from "../api/client";
import { assets } from "../assets/frontend_assets/assets";
import RelativeProduct from "../components/RelativeProduct";
import { useSSRData, useSiteUrl } from "../context/SSRDataContext";
import { availability, clampQty, maxQty, sizeStock, toneClass } from "../lib/stock";

const Product = () => {

  const {productId} = useParams();
  const {currency,addToCart,wishlist,toggleWishlist,isAdmin} = useContext(ShopContext);
  const ssr = useSSRData();
  const siteUrl = useSiteUrl();
  const ssrProduct = ssr?.route === 'product' && String(ssr.product?.id) === productId ? ssr.product : null;
  const [productData,setProductData] = useState(ssrProduct);
  const [error,setError] = useState(null);
  const [image,setImage] =useState(ssrProduct?.images?.[0] || '');
  const [size,setSize] = useState('');
  const [quantity, setQuantity] = useState(1);
  const [adding, setAdding] = useState(false);
  const skipFirstFetch = useRef(Boolean(ssrProduct));

  useEffect(()=>{
    if (skipFirstFetch.current) {
      skipFirstFetch.current = false;
      return undefined;
    }
    let cancelled = false;
    setProductData(null);
    setError(null);
    setSize('');
    setQuantity(1);
    api.product(productId)
      .then((item)=>{
        if(cancelled) return;
        setProductData(item);
        setImage(item.images[0]);
      })
      .catch((e)=>!cancelled && setError(e));
    return ()=>{ cancelled = true };
  },[productId])

  useEffect(() => {
    if (productData?.name) document.title = `${productData.name} | Forever`;
  }, [productData?.name]);

  // Absolute URL from the site origin the server used (PUBLIC_SITE_URL or the request host), so the
  // server-rendered share links are already absolute and identical to the hydrated ones.
  const shareUrl = `${siteUrl}/product/${productId}`;
  const facebookShare = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`;
  const telegramShare = `https://t.me/share/url?url=${encodeURIComponent(shareUrl)}&text=${encodeURIComponent(productData?.name || '')}`;

  if (error) return <p className="text-center text-red-500 py-20">{error.message}</p>

  if (!productData) return <div className="opacity-0"></div>;

  const status = availability(productData, size);
  const sizeMax = size ? maxQty(productData, size) : 0;
  // Nothing buyable: the product is out of stock everywhere, or the chosen size just ran out.
  const cannotBuy = !productData.inStock || (size && sizeMax === 0);

  const pickSize = (item) => {
    setSize(item);
    setQuantity((q) => clampQty(q, maxQty(productData, item)));
  };

  // Re-reads the product so the size buttons / "Only N left" reflect the stock the server just reported.
  const refreshStock = async () => {
    try {
      const fresh = await api.product(productData.id);
      setProductData(fresh);
      if (size) setQuantity((q) => clampQty(q, maxQty(fresh, size)));
    } catch { /* keep what we have */ }
  };

  const onAdd = async () => {
    setAdding(true);
    try {
      const result = await addToCart(productData.id, size, quantity);
      if (result?.error?.code === 'OUT_OF_STOCK') await refreshStock();
    } finally {
      setAdding(false);
    }
  };

  return (
    <div className="border-t pt-10 transition-opacity ease-in duration-500 opacity-100">
      {/* Product Data */}
      <div className="flex gap-12 sm:gap-12 flex-col sm:flex-row">
      {/* Product IMG */}
        <div className="flex-1 flex flex-col-reverse gap-3 sm:flex-row">
          <div className="flex sm:flex-col overflow-x-auto sm:overflow-y-scroll justify-between sm:justify-normal sm:w-[18.7%] w-full">
            {
              productData.images.map((item,index)=>(
                <img onClick={()=>setImage(item)} src={item} key={index} className="w[-24%] sm:w-full sm:mb-3 flex-shrink-0 cursor-pointer " alt="" />
              ))
            }
          </div>
          <div className="w-full sm:w-[80%] ">
            <img className="w-full h-auto" src={image} alt={productData.name} />
          </div>
        </div>
        {/* Product Description */}
        <div className="flex-1">
          <h1 className="font-medium text-2xl mt-2">{productData.name}</h1>
          <div className="flex items-center gap-1 mt-2">
            <img src={assets.star_icon} alt="" className="w-3 5" />
            <img src={assets.star_icon} alt="" className="w-3 5" />
            <img src={assets.star_icon} alt="" className="w-3 5" />
            <img src={assets.star_icon} alt="" className="w-3 5" />
            <img src={assets.star_dull_icon} alt="" className="w-3 5" />
            <p className="pl-2">(122)</p>
          </div>
          <p className="mt-5 text-3xl font-medium" data-testid="product-price">{currency}{productData.price} </p>
          {/* Real per-size stock from the API: overall availability until a size is picked, then that size's. */}
          <p className="mt-2 text-sm" data-testid="stock-status" aria-live="polite">
            <span className={toneClass[status.tone]}>● {status.text}</span>
            {size && <span className="text-gray-500"> · size {size}</span>}
          </p>
          <p className="mt-5 text-gray-600 md:w-4/5">{productData.description}</p>
          <div className="flex flex-col gap-4 my-8">
            <p>Select Size</p>
            <div className="flex gap-2">
              {productData.sizes.map((item,index)=>{
                const soldOut = sizeStock(productData, item) === 0;
                return (
                  <button key={index} type="button" onClick={()=>pickSize(item)} disabled={soldOut} aria-pressed={item === size}
                    title={soldOut ? `Size ${item} is out of stock` : undefined}
                    aria-label={soldOut ? `Size ${item} (out of stock)` : `Size ${item}`}
                    className={`border py-3 px-4 bg-gray-300 rounded-md ${item=== size ? 'bg-orange-300' : ''} ${soldOut ? 'cursor-not-allowed opacity-40 line-through' : ''}`}>
                    {item}
                  </button>
                );
              })}
            </div>
          </div>
          <div className="flex flex-col gap-2 mb-8">
            <p>Quantity</p>
            <div className="flex items-center gap-2 w-fit">
              <button type="button" aria-label="Decrease quantity" onClick={()=>setQuantity((q)=>Math.max(1, q-1))}
                className="w-9 h-9 border rounded-md text-lg disabled:opacity-40" disabled={quantity<=1 || cannotBuy}>−</button>
              <input type="number" min={1} max={size ? Math.max(1, sizeMax) : undefined} value={quantity} aria-label="Quantity" disabled={cannotBuy}
                onChange={(e)=>{
                  if (e.target.value === '') return;
                  setQuantity(clampQty(e.target.value, size ? sizeMax : 99));
                }}
                className="w-14 h-9 border rounded-md text-center disabled:opacity-40 [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none" />
              <button type="button" aria-label="Increase quantity" onClick={()=>setQuantity((q)=>clampQty(q+1, size ? sizeMax : 99))}
                className="w-9 h-9 border rounded-md text-lg disabled:opacity-40" disabled={cannotBuy || quantity >= (size ? sizeMax : 99)}>+</button>
            </div>
            {!size && productData.inStock && <p className="text-xs text-gray-500">Choose a size to see how many are left.</p>}
          </div>
          {!isAdmin && (
            <div className="flex gap-3">
              <button type="button" onClick={onAdd} disabled={cannotBuy || adding}
                className="bg-black text-white px-8 py-3 text-sm active:bg-gray-700 disabled:bg-gray-400 disabled:cursor-not-allowed">
                {!productData.inStock ? 'Out of stock' : adding ? 'Adding...' : 'Add to Cart'}
              </button>
              <button type="button" onClick={()=>toggleWishlist(productData)} className="border border-black px-5 py-3 text-sm">
                {wishlist.some((item) => item.id === productData.id) ? '♥ Saved' : '♡ Wishlist'}
              </button>
            </div>
          )}
          <div className="flex gap-3 mt-4">
            <a href={facebookShare} target="_blank" rel="noopener noreferrer" aria-label="Share on Facebook"
              className="flex items-center gap-2 border border-gray-300 rounded px-4 py-2 text-xs text-gray-600 hover:border-black hover:text-black">
              Share on Facebook
            </a>
            <a href={telegramShare} target="_blank" rel="noopener noreferrer" aria-label="Share on Telegram"
              className="flex items-center gap-2 border border-gray-300 rounded px-4 py-2 text-xs text-gray-600 hover:border-black hover:text-black">
              Share on Telegram
            </a>
          </div>
          <hr className="mt-8 sm:w-4/5"/>
          <div className="text-sm text-gray-500 mt-5 flex flex-col gap-1">
              <p>100% Original Products.</p>
              <p>Cash On Delivery</p>
              <p>Easy And Exchanged Policy Within 7 Days</p>
          </div>
        </div>
      </div>

      {/* ----Description & Review---- */}
      <div className="mt-20">
        <div className="flex">
          <p className="border px-5 py-3 text-sm">Description</p>
          <p className="border px-5 py-3 text-sm">Review(122)</p>
        </div>
        {/* Description */}
        <div className="flex flex-col gap-4 border px-6 py-6 text-sm text-gray-500">
          <p>Experience unmatched comfort and style with our Premium Cotton T-Shirt, crafted from 100% high-quality cotton. Designed for a perfect fit, this t-shirt offers breathability and durability, making it ideal for everyday wear.Whether you're dressing up for a casual day out or lounging at home, this t-shirt provides the ultimate combination of softness and style. Don't miss out on adding this staple piece to your wardrobe!</p>
          <p>Experience unmatched comfort and style with our Premium Cotton T-Shirt, crafted from 100% high-quality cotton. Designed for a perfect fit, this t-shirt offers breathability and durability, making it ideal for everyday wear.Whether you're dressing up for a casual day out or lounging at home, this t-shirt provides the ultimate combination of softness and style. Don't miss out on adding this staple piece to your wardrobe!</p>
        </div>
        {/* Display Relative Products */}
        <RelativeProduct productId={productData.id}/>
      </div>
    </div>
  )
}

export default Product
