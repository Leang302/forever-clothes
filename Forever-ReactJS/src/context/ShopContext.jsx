//ShopContext
import { createContext, useCallback, useEffect, useState } from "react";
import { toast } from 'react-toastify';
import { useNavigate } from "react-router-dom";
import { api, guestSession, session } from "../api/client";
import ConfirmDialog from "../components/ConfirmDialog";

export const ShopContext = createContext();

const EMPTY_CART = { items: [], itemCount: 0, subtotal: 0, deliveryFee: 0, total: 0 };

// Who the shopper is:
//  - logged in (`user` set, login tokens in `forever.tokens`): their account cart, orders, wishlist;
//  - anonymous with a guest cart session (token in `forever.guestSession`, sent as X-Guest-Session on
//    cart/checkout calls only): a server-side cart and guest checkout, but NEVER a login — `user` stays null;
//  - anonymous without one: an empty cart; a guest session is only started by the first "Add to cart".
// The two carts are never merged: logging in ends the guest session (its cart is discarded server-side).
const ShopContextProvider = (props) => {
   const currency = '$';
   const navigate = useNavigate();
   const [search, setSearch] = useState('');
   const [showSearch, setShowSearch] = useState(false);
   const [user, setUser] = useState(null);
   const [authReady, setAuthReady] = useState(!session.hasSession());
   // Whether this browser holds a guest cart session. Read lazily from localStorage on the client (false
   // during SSR); only the client-rendered checkout route guard depends on it, so hydration is unaffected.
   const [hasGuestCart, setHasGuestCart] = useState(() => !session.hasSession() && guestSession.has());
   const [cart, setCart] = useState(EMPTY_CART);
   const [wishlist, setWishlist] = useState([]);

   const loadCart = useCallback(async () => {
      // Nobody to load a cart for: don't call the API (and never start a guest session just to look).
      if (!session.hasSession() && !guestSession.has()) {
         setCart(EMPTY_CART);
         return;
      }
      try {
         setCart(await api.cart());
      } catch (e) {
         // An expired guest session was already forgotten by the API client; the cart is simply empty now.
         if (e.status === 401 && !session.hasSession()) return;
         toast.error(e.message);
      }
   }, []);

   // Restore a saved login (or guest cart) on page load.
   useEffect(() => {
      session.onExpired(() => {
         setUser(null);
         setCart(EMPTY_CART);
         setWishlist([]);
         toast.info('Your session expired, please log in again');
      });
      guestSession.onExpired(() => {
         setHasGuestCart(false);
         setCart(EMPTY_CART);
      });
      session.onAdminForbidden(async () => {
         // The server says this account is not an admin (anymore): refresh who we are and leave quietly.
         try { setUser(await api.me()); } catch { /* keep the current user */ }
         navigate('/', { replace: true });
      });
      if (!session.hasSession()) {
         if (guestSession.has()) loadCart();
         return;
      }
      // Logged in: a leftover guest session (shouldn't exist) is ended, never merged.
      if (guestSession.has()) guestSession.end();
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

   // Called with the AuthResponse of login / verify-email. The guest cart session is ended first (best
   // effort) and forgotten: the account only ever sees its own cart and orders, nothing is merged.
   const startSession = async (res) => {
      await guestSession.end();
      setHasGuestCart(false);
      setCart(EMPTY_CART);
      session.set(res);
      setUser(res.user);
      await loadCart();
      setWishlist(await api.wishlist());
   };

   // Logging out goes through a confirmation; `logout` itself stays immediate for session expiry etc.
   const [confirmingLogout, setConfirmingLogout] = useState(false);
   const requestLogout = () => setConfirmingLogout(true);

   // After logout the shopper is a fresh anonymous visitor: empty cart until they add something.
   const logout = async () => {
      try {
         const stored = JSON.parse(localStorage.getItem('forever.tokens'));
         if (stored?.refreshToken) await api.logout(stored.refreshToken);
      } catch { /* the token is dropped locally either way */ }
      session.clear();
      guestSession.clear();
      setHasGuestCart(false);
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

   // Sends a cart change as the logged-in customer, or as the guest cart session — which is started here,
   // lazily, on the first add (concurrent adds share one new session). If the stored guest session turns
   // out to have expired, one fresh session is started and the change retried once.
   const guestCartCall = async (call, { start }) => {
      if (session.hasSession()) return call();
      if (start) await guestSession.ensure();
      try {
         return await call();
      } catch (e) {
         if (!(start && e.status === 401 && !session.hasSession())) throw e;
         await guestSession.ensure();
         return call();
      } finally {
         setHasGuestCart(!session.hasSession() && guestSession.has());
      }
   };

   // Resolves { ok: true } or { ok: false, error } (error.code 'OUT_OF_STOCK' when the API's 409 says stock
   // changed underneath), after showing the toast either way, so callers can refresh their stock display.
   // Anonymous shoppers add to a guest cart: no login or registration prompt.
   const addToCart = async (productId, size, quantity = 1) => {
      if (!size) {
         toast.error('Please Select Product Size');
         return { ok: false };
      }
      try {
         setCart(await guestCartCall(() => api.addToCart(productId, size, quantity), { start: true }));
         toast.success(`Added to cart (${quantity} × size ${size})`);
         return { ok: true };
      } catch (e) {
         toast.error(e.message);
         return { ok: false, error: e };
      }
   };

   const updateQuantity = async (productId, size, quantity) => {
      try {
         setCart(await guestCartCall(() => api.setCartQuantity(productId, size, quantity), { start: false }));
         return { ok: true };
      } catch (e) {
         if (e.status === 401 && !session.hasSession()) {
            toast.info('Your cart has expired. Add items again to start a new one');
            return { ok: false, error: e };
         }
         toast.error(e.message);
         // The line may have changed (e.g. stock dropped): show the server's current view of the cart.
         if (e.code === 'OUT_OF_STOCK') loadCart();
         return { ok: false, error: e };
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
      hasGuestCart,
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
