//relativeProduct.jsx
import { api } from "../api/client";
import Title from './Title'
import useApi from "./useApi";
import ProductGridSection from "./ProductGridSection";

const RelativeProduct = ({ productId }) => {
  const { data, loading, error } = useApi(() => api.related(productId, 5), [productId]);

  return (
   <div className="my-24">
      <div className="text-center text-3xl py-2">
        <Title text1={'RELATED'} text2={'Product'}/>
      </div>
      <ProductGridSection products={data || []} loading={loading} error={error} />
   </div>
  );
};

export default RelativeProduct;
