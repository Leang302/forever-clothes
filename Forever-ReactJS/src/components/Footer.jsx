import { assets } from "../assets/frontend_assets/assets"
import { Link } from "react-router-dom"

const Footer = () => {
  return (
   <footer className="mt-32 border-t border-gray-200 pt-12 text-sm">
   <div className="grid gap-10 pb-10 sm:grid-cols-[2fr_1fr_1.3fr]">
      <div>
         <img src={assets.logo} className="mb-5 w-32" alt="Forever" />
         <p className="max-w-md leading-6 text-gray-500">Contemporary clothing and everyday essentials selected for quality, comfort, and timeless style.</p>
      </div>
      <div>
         <p className="mb-5 font-medium uppercase tracking-wider text-gray-900">Company</p>
         <ul className="flex flex-col gap-2 text-gray-600">
            <li><Link className="hover:text-black" to="/">Home</Link></li>
            <li><Link className="hover:text-black" to="/collection">Collection</Link></li>
            <li><Link className="hover:text-black" to="/about">About us</Link></li>
            <li><Link className="hover:text-black" to="/contact">Contact</Link></li>
         </ul>
      </div>
      <div>
         <p className="mb-5 font-medium uppercase tracking-wider text-gray-900">Contact</p>
         <ul className="flex flex-col gap-2 text-gray-600">
            <li><a className="hover:text-black" href="tel:+85515552284">015 552 284</a></li>
            <li><a className="break-all hover:text-black" href="mailto:chhungsim.chuo@gmail.com">chhungsim.chuo@gmail.com</a></li>
            <li className="pt-2 text-gray-400">Customer support for orders, delivery, and product enquiries.</li>
         </ul>
      </div>
    </div>
    <div className="flex flex-col items-center justify-between gap-2 border-t py-5 text-gray-400 sm:flex-row">
      <p>&copy; {new Date().getFullYear()} Forever. All rights reserved.</p>
      <p>Secure shopping · Quality products · Customer support</p>
    </div>
   </footer>
    
  )
}

export default Footer
