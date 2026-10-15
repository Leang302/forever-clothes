//Cart.jsx
import { useContext } from "react"
import { ShopContext } from "../context/ShopContext"
import Title from './../components/Title';
import { assets } from "../assets/frontend_assets/assets";
import CartTotal from "../components/CartTotal";

const Cart = () => {
  const {currency,cart,updateQuantity,navigate} = useContext(ShopContext);

  return (
    <div className="border-t pt-14">
      <div className="text-2xl mb-3 ">
      <Title text1={'YOUR'} text2={'cart'}/>
      </div>
      {cart.items.length === 0 && (
        <div className="py-16 text-center text-gray-500">
          <p>Your cart is empty</p>
          <button onClick={()=>navigate('/collection')} className="mt-6 bg-black text-white text-sm py-3 px-7">START SHOPPING</button>
        </div>
      )}
      {
        cart.items.map((item)=>(
            <div key={item.id} className="py-4 border-t border-b text-gray-700 grid grid-cols-[4fr_0.5fr_0.5fr] sm:grid-cols-[4fr_2fr_0.5fr] items-center gap-4">
              <div className="flex items-start gap-6">
                <img onClick={()=>navigate(`/product/${item.productId}`)} className="w-1/6 sm:w-20 cursor-pointer" src={item.image} alt="" />
                <div>
                  <p className="text-sm font-medium sm:text-lg">{item.name}</p>
                  <div className="flex items-center gap-5 mt-2">
                    <p>{currency}{item.price}</p>
                    <p className="px-2 sm:px-3 sm:py-1 border bg-slate-50">{item.size}</p>
                  </div>
                </div>
              </div>
              <input
                key={`${item.id}-${item.quantity}`}
                onChange={(e)=>{
                  const qty = Number(e.target.value);
                  if (qty >= 1 && qty <= 99) updateQuantity(item.productId, item.size, qty);
                }}
                className="border sm:max-w-20 max-w-10 px-1 sm:py-2 py-1" type="number" min={1} max={99} defaultValue={item.quantity} />
              <img onClick={()=>updateQuantity(item.productId,item.size,0)}  className="w-4 mr-4 cursor-pointer" src={assets.bin_icon} alt="" />
            </div>
        ))
      }
      {cart.items.length > 0 && (
        <div className="flex justify-end my-20 ">
          <div className="w-full sm:w-[450px]">
            <CartTotal/>
            <div className="w-full text-end">
            <button onClick={()=>navigate('/place-order')} className="uppercase bg-black text-white text-sm my-8 py-3 px-7"> Proceed to checkout</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default Cart
