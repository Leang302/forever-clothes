import { useContext } from "react";
import { Navigate, useLocation } from "react-router-dom";
import { ShopContext } from "../context/ShopContext";

// Pages that need a logged-in user (cart, checkout, orders).
// customerOnly pages (shopping features) send admins to their panel instead.
const RequireAuth = ({ children, customerOnly = false }) => {
  const { user, isAdmin, authReady } = useContext(ShopContext);
  const location = useLocation();

  if (!authReady) return <div className="py-20 text-center text-gray-400">Loading...</div>;
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  if (customerOnly && isAdmin) return <Navigate to="/admin" replace />;
  return children;
};

export default RequireAuth;
