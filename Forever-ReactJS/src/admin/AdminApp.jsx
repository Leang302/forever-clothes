import { Routes, Route, Navigate } from "react-router-dom";
import RequireAdmin from "./RequireAdmin";
import AdminLayout from "./AdminLayout";
import Dashboard from "./pages/Dashboard";
import Products from "./pages/Products";
import ProductForm from "./pages/ProductForm";
import Orders from "./pages/Orders";
import Inventory from "./pages/Inventory";
import Customers from "./pages/Customers";
import Categories from "./pages/Categories";
import Coupons from "./pages/Coupons";

const AdminApp = () => (
  <Routes>
    <Route element={<RequireAdmin />}>
      <Route element={<AdminLayout />}>
        <Route index element={<Dashboard />} />
        <Route path="products" element={<Products />} />
        <Route path="products/new" element={<ProductForm />} />
        <Route path="products/:id/edit" element={<ProductForm />} />
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
