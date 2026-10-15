import { Routes, Route, Navigate, useParams } from "react-router-dom";
import RequireAdmin from "./RequireAdmin";
import AdminLayout from "./AdminLayout";
import Dashboard from "./pages/Dashboard";
import Products from "./pages/Products";
import Orders from "./pages/Orders";
import Inventory from "./pages/Inventory";
import Customers from "./pages/Customers";
import Categories from "./pages/Categories";
import Coupons from "./pages/Coupons";

const EditProductRedirect = () => {
  const { id } = useParams();
  return <Navigate to={`/admin/products?product=${encodeURIComponent(id)}`} replace />;
};

const AdminApp = () => (
  <Routes>
    <Route element={<RequireAdmin />}>
      <Route element={<AdminLayout />}>
        <Route index element={<Dashboard />} />
        <Route path="products" element={<Products />} />
        {/* Old product form URLs open the drawer on the Products page. */}
        <Route path="products/new" element={<Navigate to="/admin/products?product=new" replace />} />
        <Route path="products/:id/edit" element={<EditProductRedirect />} />
        <Route path="orders" element={<Orders />} />
        <Route path="inventory" element={<Inventory />} />
        <Route path="customers" element={<Customers />} />
        <Route path="categories" element={<Categories />} />
        <Route path="coupons" element={<Coupons />} />
        <Route path="management" element={<Navigate to="/admin/inventory" replace />} />
        <Route path="*" element={<Navigate to="/admin" replace />} />
      </Route>
    </Route>
  </Routes>
);

export default AdminApp;
