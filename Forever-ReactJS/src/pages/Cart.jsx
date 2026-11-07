//Cart.jsx
import { useContext, useState } from "react"
import { ShopContext } from "../context/ShopContext"
import Title from './../components/Title';
import { assets } from "../assets/frontend_assets/assets";
import CartTotal from "../components/CartTotal";
import { MAX_QTY, clampQty, lineProblem } from "../lib/stock";

const money = (v) => Number(v).toFixed(2);

const Cart = () => {
  const {currency,cart,updateQuantity,navigate} = useContext(ShopContext);
  // Lines left out of this checkout. Tracking the unticked ones means newly added items start ticked.
  const [unselected, setUnselected] = useState(() => new Set());
  const selectedItems = cart.items.filter((item) => !unselected.has(item.id));
  const allSelected = selectedItems.length === cart.items.length;
  const blocked = selectedItems.filter((item) => lineProblem(item));
  const toggle = (id) => setUnselected((prev) => {
    const next = new Set(prev);
    if (next.has(id)) next.delete(id); else next.add(id);
    return next;
  });
  const toggleAll = () => setUnselected(allSelected ? new Set(cart.items.map((item) => item.id)) : new Set());
  const checkout = () => {
    if (blocked.length) return;
    navigate(allSelected ? '/place-order' : `/place-order?items=${selectedItems.map((item) => item.id).join(',')}`);
  };

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
      {cart.items.length > 0 && (
        <label className="flex items-center gap-3 py-3 text-sm text-gray-600 cursor-pointer">
          <input type="checkbox" className="w-4 h-4 accent-black" checked={allSelected} onChange={toggleAll} />
          Select all ({selectedItems.length}/{cart.items.length})
        </label>
      )}
      {
        cart.items.map((item)=>{
          const problem = lineProblem(item);
          const limit = Math.min(MAX_QTY, Math.max(0, item.stock ?? MAX_QTY));
          return (
            <div key={item.id} data-testid="cart-line" data-line-id={item.id}
              className={`py-4 border-t border-b text-gray-700 grid grid-cols-[4fr_0.5fr_0.5fr] sm:grid-cols-[4fr_2fr_0.5fr] items-center gap-4 ${problem ? 'bg-red-50' : ''}`}>
              <div className="flex items-start gap-4 sm:gap-6">
                <input type="checkbox" aria-label={`Include ${item.name} in checkout`} className="mt-1 w-4 h-4 shrink-0 accent-black cursor-pointer"
                  checked={!unselected.has(item.id)} onChange={() => toggle(item.id)} />
                <img onClick={()=>navigate(`/product/${item.productId}`)} className="w-1/6 sm:w-20 cursor-pointer" src={item.image} alt="" />
                <div>
                  <p className="text-sm font-medium sm:text-lg">{item.name}</p>
                  <div className="flex items-center gap-5 mt-2">
                    <p data-testid="line-unit-price">{currency}{money(item.price)} <span className="text-xs text-gray-500">each</span></p>
                    <p className="px-2 sm:px-3 sm:py-1 border bg-slate-50">{item.size}</p>
                  </div>
                  <p className="mt-1 text-sm" data-testid="line-subtotal">
                    <span className="text-gray-500">Subtotal ({item.quantity} × {currency}{money(item.price)}):</span>{' '}
                    <b>{currency}{money(item.lineTotal ?? Number(item.price) * item.quantity)}</b>
                  </p>
                  {problem ? (
                    <p role="alert" className="mt-1 text-sm text-red-600" data-testid="line-stock-problem">
                      {problem}
                      {item.stock > 0 && (
                        <button type="button" onClick={() => updateQuantity(item.productId, item.size, item.stock)} className="ml-2 underline">
                          Set to {item.stock}
                        </button>
                      )}
                    </p>
                  ) : item.stock != null && item.stock <= 5 ? (
                    <p className="mt-1 text-xs text-amber-600">Only {item.stock} left in this size</p>
                  ) : null}
                </div>
              </div>
              <input
                key={`${item.id}-${item.quantity}`}
                aria-label={`Quantity of ${item.name} (size ${item.size})`}
                disabled={limit === 0}
                onChange={(e)=>{
                  const raw = e.target.value;
                  if (raw === '') return;
                  const qty = clampQty(raw, limit);
                  if (String(qty) !== raw) e.target.value = String(qty); // e.g. typed 12 with 3 left -> 3
                  if (qty !== item.quantity) updateQuantity(item.productId, item.size, qty);
                }}
                className="border sm:max-w-20 max-w-10 px-1 sm:py-2 py-1 disabled:opacity-40" type="number" min={1} max={Math.max(1, limit)} defaultValue={item.quantity} />
              <img onClick={()=>updateQuantity(item.productId,item.size,0)} role="button" aria-label={`Remove ${item.name} (size ${item.size})`} className="w-4 mr-4 cursor-pointer" src={assets.bin_icon} alt="" />
            </div>
          );
        })
      }
      {cart.items.length > 0 && (
        <div className="flex justify-end my-20 ">
          <div className="w-full sm:w-[450px]">
            <CartTotal items={selectedItems}/>
            {blocked.length > 0 && (
              <p role="alert" className="mt-4 text-sm text-red-600">
                {blocked.length === 1 ? '1 item has' : `${blocked.length} items have`} less stock than the quantity in your cart. Adjust or remove {blocked.length === 1 ? 'it' : 'them'} (or untick {blocked.length === 1 ? 'it' : 'them'}) to check out.
              </p>
            )}
            <div className="w-full text-end">
            <button onClick={checkout} disabled={selectedItems.length === 0 || blocked.length > 0} className="uppercase bg-black text-white text-sm my-8 py-3 px-7 disabled:bg-gray-400">
              {selectedItems.length === 0 ? 'Select items to checkout' : `Checkout ${selectedItems.length} item${selectedItems.length === 1 ? '' : 's'}`}
            </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default Cart
