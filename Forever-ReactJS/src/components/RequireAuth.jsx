import { useContext } from "react";
import { Navigate, useLocation } from "react-router-dom";
import { ShopContext } from "../context/ShopContext";

// Pages that need a logged-in user (orders, profile, wishlist).
// customerOnly pages (shopping features) send admins to their panel instead.
// `anonymous` is what a visitor who is NOT logged in sees instead of the login redirect: the guest shopping
// pages (cart, checkout, order confirmation) render for them without any login. Visiting a page never starts
// a guest cart session; only the first "Add to cart" does (ShopContext.addToCart).
const RequireAuth = ({ children, customerOnly = false, anonymous = null }) => {
  const { user, isAdmin, authReady } = useContext(ShopContext);
  const location = useLocation();

  if (!authReady) return <div className="py-20 text-center text-gray-400">Loading...</div>;
  if (!user) {
    if (anonymous) return anonymous;
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  if (customerOnly && isAdmin) return <Navigate to="/admin" replace />;
  return children;
};

export default RequireAuth;
