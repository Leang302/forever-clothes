import { useContext } from "react";
import { Navigate, Outlet } from "react-router-dom";
import { ShopContext } from "../context/ShopContext";

/**
 * Route guard for everything under /admin (a layout route that renders <Outlet/> when allowed).
 * Anyone who is not a signed-in ADMIN is sent to the home page without any message, so the page
 * does not reveal that an admin area exists. The API enforces the same rule on every request.
 */
const RequireAdmin = () => {
  const { user, authReady } = useContext(ShopContext);

  if (!authReady) return <div className="min-h-screen grid place-items-center text-gray-400">Loading...</div>;
  if (!user || user.role !== 'ADMIN') return <Navigate to="/" replace />;
  return <Outlet />;
};

export default RequireAdmin;
