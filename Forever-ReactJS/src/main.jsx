import { createRoot } from 'react-dom/client'
import App from './App.jsx'
import './index.css'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import ShopContextProvider from './context/ShopContext.jsx'

// A data router (rather than <BrowserRouter>) is needed for useBlocker, which forms use to confirm before
// leaving with unsaved changes. App keeps declaring its pages with <Routes> under this catch-all route.
const router = createBrowserRouter([
  {
    path: '*',
    element: (
      <ShopContextProvider>
        <App/>
      </ShopContextProvider>
    ),
  },
])

createRoot(document.getElementById('root')).render(<RouterProvider router={router} />)
