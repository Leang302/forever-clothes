import { api } from "../api/client";
import Title from "./Title";
import useApi from "./useApi";
import ProductGridSection from "./ProductGridSection";

const BestSeller = () => {
   const { data, loading, error } = useApi(() => api.bestsellers(5), []);

   return (
      <div className="my-10">
         <div className="text-center text-3xl py-8">
            <Title text1={'Best'} text2={'Seller'} />
            <p className="w-3/4 m-auto text-xs sm:text-sm md:text-base text-gray-600">
            Our best seller is a versatile, stylish piece that combines comfort with modern design, making it a must-have in any wardrobe. Loved for its perfect fit and premium quality, its a go-to choice for fashion enthusiasts.
            </p>
         </div>
         <ProductGridSection products={data || []} loading={loading} error={error} />
      </div>
   )
}

export default BestSeller
