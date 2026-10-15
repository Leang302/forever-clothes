//Product.jsx
/* eslint-disable react/no-unescaped-entities */
import { useContext, useEffect, useState } from "react";
import { useParams } from "react-router-dom"
import { ShopContext } from "../context/ShopContext";
import { api } from "../api/client";
import { assets } from "../assets/frontend_assets/assets";
import RelativeProduct from "../components/RelativeProduct";

const Product = () => {
  
  const {productId} = useParams();
  const {currency,addToCart,wishlist,toggleWishlist,isAdmin} = useContext(ShopContext);
  const [productData,setProductData] = useState(null);
  const [error,setError] = useState(null);
  const [image,setImage] =useState('');
  const [size,setSize] = useState('');

  useEffect(()=>{
    let cancelled = false;
    setProductData(null);
    setError(null);
    setSize('');
    api.product(productId)
      .then((item)=>{
        if(cancelled) return;
        setProductData(item);
        setImage(item.images[0]);
      })
      .catch((e)=>!cancelled && setError(e));
    return ()=>{ cancelled = true };
  },[productId])

  if (error) return <p className="text-center text-red-500 py-20">{error.message}</p>

  return productData ?  (
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
            <img className="w-full h-auto" src={image} alt="" />
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
          <p className="mt-5 text-3xl font-medium">{currency}{productData.price} </p>
          <p className="mt-5 text-gray-600 md:w-4/5">{productData.description}</p>
          <div className="flex flex-col gap-4 my-8">
            <p>Select Size</p>
            <div className="flex gap-2">
              {productData.sizes.map((item,index)=>(
                <button onClick={()=>setSize(item)} className={`border py-3 px-4 bg-gray-300 rounded-md ${item=== size ? 'bg-orange-300' : ''}`} key={index}>
                  {item}
                </button>
              ))}
            </div>  
          </div>
          {!isAdmin && (
            <div className="flex gap-3">
              <button onClick={()=>addToCart(productData.id ,size)} className="bg-black text-white px-8 py-3 text-sm active:bg-gray-700">Add to Cart</button>
              <button onClick={()=>toggleWishlist(productData)} className="border border-black px-5 py-3 text-sm">
                {wishlist.some((item) => item.id === productData.id) ? '♥ Saved' : '♡ Wishlist'}
              </button>
            </div>
          )}
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
  ) : <div className="opacity-0"></div>
}

export default Product
