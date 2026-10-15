//CartTotal.jsx
import { useContext } from "react"
import { ShopContext } from "../context/ShopContext"
import Title from './Title';

const money = (v) => Number(v).toFixed(2);

const CartTotal = () => {
   const { currency, cart } = useContext(ShopContext);
  return (
    <div className="w-full">
      <div className="text-2xl ">
         <Title text1={'CART'} text2={'totals'}/>
      </div>

      <div className="flex-col flex gap-2 mt-2 text-sm">
         <div className="justify-between flex">
            <p>Sub Total</p>
            <p>{currency}{money(cart.subtotal)}</p>
         </div>
         <hr />
         <div className="flex justify-between">
            <p>Shipping Fee</p>
            <p>{currency}{money(cart.deliveryFee)}</p>
         </div>
         <hr />
         <div className="flex justify-between">
            <p>Total</p>
            <p>{currency}{money(cart.total)}</p>
         </div>
      </div>
    </div>
  )
}

export default CartTotal
