import { useSearchParams } from "react-router-dom";
import ProductForm from "../pages/ProductForm";
import { PRODUCT_CATEGORY_PARAM, PRODUCT_PARAM, PRODUCT_SUB_PARAM, announceProductSaved } from "../productDrawer";

// Shows the add/edit product drawer when the URL has `?product=…`. Rendered once by AdminLayout.
const ProductDrawerHost = () => {
  const [params, setParams] = useSearchParams();
  const productId = params.get(PRODUCT_PARAM);
  if (!productId) return null;

  const close = () =>
    setParams(
      (prev) => {
        const next = new URLSearchParams(prev);
        [PRODUCT_PARAM, PRODUCT_CATEGORY_PARAM, PRODUCT_SUB_PARAM].forEach((p) => next.delete(p));
        return next;
      },
      { replace: true },
    );

  return (
    <ProductForm
      key={productId}
      productId={productId}
      prefill={{ category: params.get(PRODUCT_CATEGORY_PARAM) || '', subCategory: params.get(PRODUCT_SUB_PARAM) || '' }}
      onClose={close}
      onSaved={() => {
        close();
        announceProductSaved();
      }}
    />
  );
};

export default ProductDrawerHost;
