// Thin fetch wrapper for the Forever API: bearer token, one automatic refresh on 401, uniform errors.
export const API_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8989').replace(/\/+$/, '');

const STORE_KEY = 'forever.tokens';

export class ApiError extends Error {
  constructor(message, { status, code, fieldErrors } = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.fieldErrors = fieldErrors;
  }
}

let tokens = readTokens();
let onSessionExpired = () => {};
let onAdminForbidden = () => {};
let refreshing = null;

function readTokens() {
  try {
    return JSON.parse(localStorage.getItem(STORE_KEY)) || null;
  } catch {
    return null;
  }
}

export const session = {
  hasSession: () => !!tokens?.refreshToken,
  set(res) {
    tokens = { accessToken: res.accessToken, refreshToken: res.refreshToken };
    localStorage.setItem(STORE_KEY, JSON.stringify(tokens));
  },
  clear() {
    tokens = null;
    localStorage.removeItem(STORE_KEY);
  },
  onExpired(fn) {
    onSessionExpired = fn;
  },
  // Called when an /api/admin/** request is refused (role missing or revoked).
  onAdminForbidden(fn) {
    onAdminForbidden = fn;
  },
};

function buildUrl(path, query) {
  const url = new URL(API_URL + path);
  Object.entries(query || {}).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') return;
    (Array.isArray(value) ? value : [value]).forEach((v) => url.searchParams.append(key, v));
  });
  return url;
}

async function refreshTokens() {
  // Share one refresh between concurrent 401s: refresh tokens are single-use.
  refreshing ??= fetch(API_URL + '/api/auth/refresh', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken: tokens.refreshToken }),
  })
    .then(async (res) => {
      if (!res.ok) {
        if ([400, 401, 403].includes(res.status)) {
          session.clear();
          onSessionExpired();
        }
        return false;
      }
      session.set(await res.json());
      return true;
    })
    .catch(() => false)
    .finally(() => {
      refreshing = null;
    });
  return refreshing;
}

async function request(path, { method = 'GET', body, query, auth = true, retried = false } = {}) {
  const headers = { Accept: 'application/json' };
  // FormData (admin image uploads) must keep the browser-generated multipart boundary.
  const isForm = typeof FormData !== 'undefined' && body instanceof FormData;
  if (body !== undefined && !isForm) headers['Content-Type'] = 'application/json';
  if (auth && tokens?.accessToken) headers.Authorization = `Bearer ${tokens.accessToken}`;

  let res;
  try {
    res = await fetch(buildUrl(path, query), {
      method,
      headers,
      body: body === undefined ? undefined : isForm ? body : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(`Cannot reach the server (${API_URL}). Is the API running?`, { code: 'NETWORK' });
  }

  if (res.status === 401 && auth && !retried && tokens?.refreshToken && (await refreshTokens())) {
    return request(path, { method, body, query, auth, retried: true });
  }
  if (res.status === 403 && path.startsWith('/api/admin')) onAdminForbidden();
  if (res.status === 204) return null;

  const text = await res.text();
  const data = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const fields = data?.fieldErrors;
    const message = (fields && Object.values(fields)[0]) || data?.message || `Request failed (${res.status})`;
    throw new ApiError(message, { status: res.status, code: data?.code, fieldErrors: fields });
  }
  return data;
}

const post = (path, body, auth = true) => request(path, { method: 'POST', body, auth });

export const api = {
  // auth
  register: (b) => post('/api/auth/register', b, false),
  verifyEmail: (b) => post('/api/auth/verify-email', b, false),
  resendOtp: (b) => post('/api/auth/resend-otp', b, false),
  login: (b) => post('/api/auth/login', b, false),
  logout: (refreshToken) => post('/api/auth/logout', { refreshToken }, false),
  forgotPassword: (b) => post('/api/auth/forgot-password', b, false),
  resetPassword: (b) => post('/api/auth/reset-password', b, false),
  // profile
  me: () => request('/api/users/me'),
  updateProfile: (body) => request('/api/users/me', { method: 'PUT', body }),
  changePassword: (body) => post('/api/users/me/change-password', body),
  addresses: () => request('/api/users/me/addresses'),
  addAddress: (body) => post('/api/users/me/addresses', body),
  deleteAddress: (id) => request(`/api/users/me/addresses/${id}`, { method: 'DELETE' }),
  // wishlist
  wishlist: () => request('/api/wishlist'),
  addWishlist: (productId) => post(`/api/wishlist/${productId}`),
  removeWishlist: (productId) => request(`/api/wishlist/${productId}`, { method: 'DELETE' }),
  // catalogue
  products: (query) => request('/api/products', { query, auth: false }),
  filters: () => request('/api/products/filters', { auth: false }),
  latest: (limit = 10) => request('/api/products/latest', { query: { limit }, auth: false }),
  bestsellers: (limit = 5) => request('/api/products/bestsellers', { query: { limit }, auth: false }),
  product: (id) => request(`/api/products/${id}`, { auth: false }),
  related: (id, limit = 5) => request(`/api/products/${id}/related`, { query: { limit }, auth: false }),
  // cart
  cart: () => request('/api/cart'),
  addToCart: (productId, size) => post('/api/cart/items', { productId, size, quantity: 1 }),
  setCartQuantity: (productId, size, quantity) =>
    request('/api/cart/items', { method: 'PUT', body: { productId, size, quantity } }),
  // orders
  placeOrder: (b) => post('/api/orders', b),
  paywayCheckout: (b) => post('/api/payway/checkout', b),
  verifyPayway: (orderId, transactionId) => post('/api/payway/verify', { orderId, transactionId }),
  abortPayway: (orderId) => post(`/api/payway/${orderId}/abort`),
  checkoutOptions: () => request('/api/checkout/options'),
  // Preview a coupon before ordering: resolves { code, description, discountType, discount, summary } or throws with the reason.
  checkCoupon: (code, subtotal) => post('/api/checkout/coupon', { code, subtotal }),
  orders: (query) => request('/api/orders', { query }),
  order: (id) => request(`/api/orders/${id}`),
  cancelOrder: (id) => post(`/api/orders/${id}/cancel`),
  // admin (ADMIN role)
  adminStats: () => request('/api/admin/stats'),
  adminProducts: (query) => request('/api/admin/products', { query }),
  adminProduct: (id) => request(`/api/admin/products/${id}`),
  adminCreateProduct: (form) => request('/api/admin/products', { method: 'POST', body: form }),
  adminUpdateProduct: (id, form) => request(`/api/admin/products/${id}`, { method: 'PUT', body: form }),
  adminSetProductActive: (id, active) =>
    request(`/api/admin/products/${id}/active`, { method: 'PATCH', query: { active } }),
  adminOrders: (query) => request('/api/admin/orders', { query }),
  adminUpdateOrderStatus: (id, status) =>
    request(`/api/admin/orders/${id}/status`, { method: 'PATCH', body: { status } }),
  adminInventory: () => request('/api/admin/inventory'),
  adminSetStock: (productId, size, stock) => request(`/api/admin/inventory/${productId}/${size}`, { method: 'PUT', body: { stock } }),
  adminCategories: () => request('/api/admin/categories'),
  adminAddCategory: (name) => post('/api/admin/categories', { name }),
  adminDeleteCategory: (id) => request(`/api/admin/categories/${id}`, { method: 'DELETE' }),
  adminCoupons: () => request('/api/admin/coupons'),
  adminAddCoupon: (body) => post('/api/admin/coupons', body),
  adminUpdateCoupon: (id, body) => request(`/api/admin/coupons/${id}`, { method: 'PUT', body }),
  adminSetCouponActive: (id, active) =>
    request(`/api/admin/coupons/${id}/active`, { method: 'PATCH', query: { active } }),
  adminDeleteCoupon: (id) => request(`/api/admin/coupons/${id}`, { method: 'DELETE' }),
  adminCustomers: () => request('/api/admin/customers'),
  adminCustomerOrders: (id, query) => request(`/api/admin/customers/${id}/orders`, { query }),
  adminAnalytics: () => request('/api/admin/analytics'),
};
