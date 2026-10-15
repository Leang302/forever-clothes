//Contact.jsx
import { assets } from "../assets/frontend_assets/assets"
import Title from "../components/Title"

const Contact = () => {
  return (
    <>
     <div className="text-center text-2xl pt-10 border-t">
      <Title text1={'Contact'} text2={'us'}/>
      </div>
      <div className="my-10 flex flex-col justify-center md:flex-row gap-10 mb-28">
        <img className="w-full md:max-w-[480px]" src={assets.contact_img} alt="" />
        <div className="flex flex-col justify-center items-start gap-6">
          <p className="font-semibold text-xl text-gray-700">Our Store</p>
          <p className="text-gray-500">Phnom Penh ,Bak tuk,Cambodia</p>
          <p className="text-gray-500">Tel: 855 12 122391 <br />Email: admin@forver.com</p>
          <p className="font-semibold text-xl text-gray-700">Careers at Forever</p>
          <p className="text-gray-500">Learn More about our team and opening.</p>
          <button className="border border-black px-8 py-3 text-black hover:bg-black hover:text-white transition-all duration-500">Explore Jobs</button>
        </div>
      </div>
    </>
  )
}

export default Contact
