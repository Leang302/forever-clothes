import { api } from "../api/client";
import Title from "./Title";
import useApi from "./useApi";
import ProductGridSection from "./ProductGridSection";

const LatestCollection = () => {
   const { data, loading, error } = useApi(() => api.latest(10), []);

   return (
      <div className="my-10">
         <div className="text-center py-8 text-3xl">
            <Title text1={'Latest'} text2={'Collection'} />
            <p className="w-3/4 m-auto text-xs sm:text-sm md:text-base text-gray-600">
               Our latest collection offers a blend of contemporary styles and timeless designs, featuring high-quality fabrics and versatile pieces perfect for any occasion. Elevate your wardrobe with our fresh, on-trend selections.
            </p>
         </div>
         <ProductGridSection products={data || []} loading={loading} error={error} />
      </div>
   );
}

export default LatestCollection;
