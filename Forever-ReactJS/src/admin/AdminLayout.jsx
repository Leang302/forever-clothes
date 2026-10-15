import { useContext, useState } from "react";
import { Link, NavLink, Outlet } from "react-router-dom";
import { ShopContext } from "../context/ShopContext";
import { assets } from "../assets/admin_assets/assets";

const Icon = ({ d }) => (
  <svg viewBox="0 0 24 24" className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
    <path d={d} />
  </svg>
);

const NAV = [
  { to: '/admin', label: 'Dashboard', end: true, icon: <Icon d="M3 12l9-8 9 8M5 10v10h5v-6h4v6h5V10" /> },
  { to: '/admin/products', label: 'Products', end: true, icon: <Icon d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" /> },
  { to: '/admin/products/new', label: 'Add product', icon: <img src={assets.add_icon} alt="" className="w-5 h-5" /> },
  { to: '/admin/orders', label: 'Orders', icon: <img src={assets.order_icon} alt="" className="w-5 h-5" /> },
  { to: '/admin/categories', label: 'Categories', icon: <Icon d="M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z" /> },
  { to: '/admin/inventory', label: 'Inventory', icon: <Icon d="M3 7l9-4 9 4-9 4-9-4zm0 5l9 4 9-4M3 17l9 4 9-4" /> },
  { to: '/admin/customers', label: 'Customers', icon: <Icon d="M16 19v-1a4 4 0 00-4-4H6a4 4 0 00-4 4v1M9 10a3 3 0 100-6 3 3 0 000 6zm13 9v-1a4 4 0 00-3-3.87M16 4.13a3 3 0 010 5.74" /> },
  { to: '/admin/coupons', label: 'Coupons', icon: <Icon d="M3 9a2 2 0 002-2V5h14v2a2 2 0 000 4v2a2 2 0 000 4v2H5v-2a2 2 0 00-2-2V9zm7-2v10" /> },
];

const linkClass = ({ isActive }) =>
  `flex items-center gap-3 px-3 py-2.5 rounded-md text-sm transition-colors ${
    isActive ? 'bg-black text-white' : 'text-gray-600 hover:bg-gray-100'
  }`;

const AdminLayout = () => {
  const { user, logout } = useContext(ShopContext);
  const [open, setOpen] = useState(false);

  return (
    <div className="min-h-screen bg-gray-50 text-gray-800">
      {/* Top bar */}
      <header className="sticky top-0 z-30 h-14 bg-white border-b flex items-center justify-between px-4 lg:pl-64">
        <div className="flex items-center gap-3 lg:hidden">
          <button onClick={() => setOpen((o) => !o)} aria-label="Menu" className="p-1">
            <Icon d="M4 6h16M4 12h16M4 18h16" />
          </button>
          <img src={assets.logo} alt="Forever" className="h-6" />
        </div>
        <div className="hidden lg:block text-sm text-gray-500">Admin panel</div>
        <div className="flex items-center gap-4 text-sm">
          <Link to="/" className="text-gray-500 hover:text-black hidden sm:inline">View store</Link>
          <span className="hidden sm:inline text-gray-700">{user.name}</span>
          <button onClick={logout} className="border border-gray-300 px-3 py-1 rounded hover:bg-gray-100">Logout</button>
        </div>
      </header>

      {/* Sidebar */}
      <aside className={`fixed top-0 left-0 z-40 h-full w-60 bg-white border-r p-4 transition-transform lg:translate-x-0 ${open ? 'translate-x-0' : '-translate-x-full'}`}>
        <div className="hidden lg:flex items-center gap-2 mb-8 mt-1 px-1">
          <img src={assets.logo} alt="Forever" className="h-7" />
        </div>
        <nav className="flex flex-col gap-1 mt-12 lg:mt-0" onClick={() => setOpen(false)}>
          {NAV.map((item) => (
            <NavLink key={item.to} to={item.to} end={item.end} className={linkClass}>
              {item.icon}
              {item.label}
            </NavLink>
          ))}
        </nav>
      </aside>
      {open && <div className="fixed inset-0 z-30 bg-black/30 lg:hidden" onClick={() => setOpen(false)} />}

      <main className="lg:pl-60">
        <div className="p-4 sm:p-6 max-w-6xl mx-auto"><Outlet /></div>
      </main>
    </div>
  );
};

export default AdminLayout;
