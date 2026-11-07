import { useContext } from "react"
import { Routes, Route, Navigate } from "react-router-dom"
import { ShopContext } from "./context/ShopContext"
import Home from "./pages/Home"
import Collection from "./pages/Collection"
import About from './pages/About';
import Contact from './pages/Contact';
import Product from './pages/Product';
import Cart from "./pages/Cart";
import Login from './pages/Login';
import PlaceOrder from './pages/PlaceOrder';
import Order from './pages/Order';
import OrderDetail from './pages/OrderDetail';
import Profile from './pages/Profile';
import NotFound from './pages/NotFound';
import Wishlist from './pages/Wishlist';
import OrderConfirmation from './pages/OrderConfirmation';
import Navbar from './components/navbar';
import Footer from "./components/Footer";
import SearchBar from './components/SearchBar';
import RequireAuth from './components/RequireAuth';
import AdminApp from './admin/AdminApp';
import { ToastContainer } from 'react-toastify';
import 'react-toastify/dist/ReactToastify.css';

// Anonymous checkout: only with a guest cart session (i.e. after adding something); otherwise back to the cart.
const GuestCheckout = () => {
  const { hasGuestCart } = useContext(ShopContext);
  return hasGuestCart ? <PlaceOrder/> : <Navigate to="/cart" replace/>;
};

const Storefront = () => (
  <div className="px-4 sm:px-[5vw] md:px-[7vw] lg:px-[9vw]">
    <Navbar/>
    <SearchBar/>
    <Routes>
      <Route path="/" element={<Home/>}/>
      <Route path="/collection" element={<Collection/>} />
      <Route path="/about" element={<About/>} />
      <Route path="/contact" element={<Contact/>} />
      <Route path="/product/:productId" element={<Product/>} />
      {/* Guests shop without logging in: the cart shows the guest cart (or the empty cart when there is no
          guest session yet — visiting it does not start one). */}
      <Route path="/cart" element={<RequireAuth customerOnly anonymous={<Cart/>}><Cart/></RequireAuth>}/>
      <Route path="/login" element={<Login/>}/>
      <Route path="/place-order" element={<RequireAuth customerOnly anonymous={<GuestCheckout/>}><PlaceOrder/></RequireAuth>}/>
      <Route path="/order" element={<RequireAuth customerOnly><Order/></RequireAuth>}/>
      <Route path="/order/:orderId" element={<RequireAuth customerOnly><OrderDetail/></RequireAuth>}/>
      <Route path="/profile" element={<RequireAuth><Profile/></RequireAuth>}/>
      {/* Account pages (orders, profile, wishlist) always require a real login. */}
      <Route path="/wishlist" element={<RequireAuth customerOnly><Wishlist/></RequireAuth>}/>
      {/* Guests see their own order through its per-tab access token (the page decides). */}
      <Route path="/order-confirmation/:orderId" element={<RequireAuth customerOnly anonymous={<OrderConfirmation/>}><OrderConfirmation/></RequireAuth>}/>
      <Route path="*" element={<NotFound/>}/>
    </Routes>
    <Footer/>
  </div>
)

// The admin panel has its own layout (sidebar), so it is routed beside the storefront, not inside it.
const App = () => (
  <>
    <ToastContainer
      position="bottom-right"
      autoClose={2200}
      pauseOnFocusLoss={false}
      newestOnTop
      limit={3}
    />
    <Routes>
      <Route path="/admin/*" element={<AdminApp/>} />
      <Route path="/*" element={<Storefront/>} />
    </Routes>
  </>
)

export default App
