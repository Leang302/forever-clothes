//CartTotal.jsx
import { useContext } from "react"
import { ShopContext } from "../context/ShopContext"
import Title from './Title';

const money = (v) => Number(v).toFixed(2);

// Totals for `items` (the lines picked for checkout), or the whole cart when not given.
// At checkout, `deliveryFee` is the chosen shipping method's fee and `discount` the applied coupon's saving.
const CartTotal = ({ items, deliveryFee: chosenFee, shippingLabel, discount = 0, couponCode }) => {
   const { currency, cart } = useContext(ShopContext);
   const lines = items ?? cart.items;
   const subtotal = items ? lines.reduce((sum, i) => sum + Number(i.price) * i.quantity, 0) : cart.subtotal;
   const deliveryFee = lines.length > 0 ? (chosenFee ?? cart.deliveryFee) : 0;
   const saving = Math.min(Number(discount) || 0, Number(subtotal));
   const total = Number(subtotal) - saving + Number(deliveryFee);
  return (
    <div className="w-full">
      <div className="text-2xl ">
         <Title text1={'CART'} text2={'totals'}/>
      </div>

      <div className="flex-col flex gap-2 mt-2 text-sm">
         {items && items.length !== cart.items.length && (
            <p className="text-gray-500">{items.length} of {cart.items.length} items selected</p>
         )}
         <div className="justify-between flex">
            <p>Sub Total</p>
            <p>{currency}{money(subtotal)}</p>
         </div>
         <hr />
         {saving > 0 && (
            <>
               <div className="flex justify-between text-green-700">
                  <p>Discount{couponCode ? ` (${couponCode})` : ''}</p>
                  <p>−{currency}{money(saving)}</p>
               </div>
               <hr />
            </>
         )}
         <div className="flex justify-between">
            <p>Shipping Fee{shippingLabel ? <span className="text-gray-500"> · {shippingLabel}</span> : null}</p>
            <p>{currency}{money(deliveryFee)}</p>
         </div>
         <hr />
         <div className="flex justify-between font-semibold text-base">
            <p>Total to pay</p>
            <p>{currency}{money(total)}</p>
         </div>
      </div>
    </div>
  )
}

export default CartTotal
