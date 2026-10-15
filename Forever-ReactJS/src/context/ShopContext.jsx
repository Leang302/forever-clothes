//ShopContext
import { createContext, useCallback, useEffect, useState } from "react";
import { toast } from 'react-toastify';
import { useNavigate } from "react-router-dom";
import { api, session } from "../api/client";
import ConfirmDialog from "../components/ConfirmDialog";

export const ShopContext = createContext();

const EMPTY_CART = { items: [], itemCount: 0, subtotal: 0, deliveryFee: 0, total: 0 };

const ShopContextProvider = (props) => {
   const currency = '$';
   const navigate = useNavigate();
   const [search, setSearch] = useState('');
   const [showSearch, setShowSearch] = useState(false);
   const [user, setUser] = useState(null);
   const [authReady, setAuthReady] = useState(!session.hasSession());
   const [cart, setCart] = useState(EMPTY_CART);
   const [wishlist, setWishlist] = useState([]);

   const loadCart = useCallback(async () => {
      try {
         setCart(await api.cart());
      } catch (e) {
         toast.error(e.message);
      }
   }, []);

   // Restore a saved session on page load.
   useEffect(() => {
      session.onExpired(() => {
         setUser(null);
         setCart(EMPTY_CART);
         setWishlist([]);
         toast.info('Your session expired, please log in again');
      });
      session.onAdminForbidden(async () => {
         // The server says this account is not an admin (anymore): refresh who we are and leave quietly.
         try { setUser(await api.me()); } catch { /* keep the current user */ }
         navigate('/', { replace: true });
      });
      if (!session.hasSession()) return;
      (async () => {
         try {
            setUser(await api.me());
            await Promise.all([loadCart(), api.wishlist().then(setWishlist)]);
         } catch {
            // network error or invalid session: stay logged out
         } finally {
            setAuthReady(true);
         }
      })();
   }, [loadCart, navigate]);

   // Called with the AuthResponse of login / verify-email.
   const startSession = async (res) => {
      session.set(res);
      setUser(res.user);
      await loadCart();
      setWishlist(await api.wishlist());
   };

   // Logging out goes through a confirmation; `logout` itself stays immediate for session expiry etc.
   const [confirmingLogout, setConfirmingLogout] = useState(false);
   const requestLogout = () => setConfirmingLogout(true);

   const logout = async () => {
      try {
         const stored = JSON.parse(localStorage.getItem('forever.tokens'));
         if (stored?.refreshToken) await api.logout(stored.refreshToken);
      } catch { /* the token is dropped locally either way */ }
      session.clear();
      setUser(null);
      setCart(EMPTY_CART);
      setWishlist([]);
      navigate('/');
   };

   const requireLogin = (message = 'Please log in to continue') => {
      if (user) return true;
      toast.info(message);
      navigate('/login', { state: { from: window.location.pathname } });
      return false;
   };

   const addToCart = async (productId, size) => {
      if (!size) {
         toast.error('Please Select Product Size');
         return;
      }
      if (!requireLogin('Please log in to add items to your cart')) return;
      try {
         setCart(await api.addToCart(productId, size));
         toast.success('Added to cart');
      } catch (e) {
         toast.error(e.message);
      }
   };

   const updateQuantity = async (productId, size, quantity) => {
      try {
         setCart(await api.setCartQuantity(productId, size, quantity));
      } catch (e) {
         toast.error(e.message);
      }
   };

   // Admins manage the shop; cart, wishlist and orders are customer-only features.
   const isAdmin = user?.role === 'ADMIN';

   const getCartCount = () => cart.itemCount;
   const getCartAmount = () => cart.subtotal;

   const toggleWishlist = async (product) => {
      if (!requireLogin('Please log in to save favourites')) return;
      const exists = wishlist.some((item) => item.id === product.id);
      try {
         if (exists) {
            await api.removeWishlist(product.id);
            setWishlist((items) => items.filter((item) => item.id !== product.id));
            toast.info('Removed from wishlist');
         } else {
            const saved = await api.addWishlist(product.id);
            setWishlist((items) => [saved, ...items]);
            toast.success('Saved to wishlist');
         }
      } catch (e) {
         toast.error(e.message);
      }
   };

   const value = {
      currency,
      delivery_fee: cart.deliveryFee,
      search,
      setSearch,
      showSearch,
      setShowSearch,
      user,
      setUser,
      isAdmin,
      authReady,
      startSession,
      logout,
      requestLogout,
      requireLogin,
      cart,
      setCart,
      loadCart,
      wishlist,
      toggleWishlist,
      addToCart,
      getCartCount,
      updateQuantity,
      getCartAmount,
      navigate
   }
   return (
      <ShopContext.Provider value={value}>
         {props.children}
         {confirmingLogout && (
            <ConfirmDialog
               title="Log out?"
               message="You will need to sign in again to see your cart, orders and wishlist."
               confirmLabel="Log out"
               cancelLabel="Stay signed in"
               onCancel={() => setConfirmingLogout(false)}
               onConfirm={() => { setConfirmingLogout(false); logout(); }}
            />
         )}
      </ShopContext.Provider>
   )
}
export default ShopContextProvider;
