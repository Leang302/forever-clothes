// Thin fetch wrapper for the Forever API: bearer token, one automatic refresh on 401, uniform errors.
export const API_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8989').replace(/\/+$/, '');

// Base URL for requests. In the browser it is always the build-time VITE_API_URL. During SSR, the runtime
// SSR_API_URL env (server-only, e.g. http://api:8989 on a Docker network) wins when set, so the SSR server
// can reach the API on an internal hostname while browsers keep using the public URL.
const baseUrl = () =>
  (import.meta.env.SSR && globalThis.process?.env?.SSR_API_URL
    ? globalThis.process.env.SSR_API_URL.replace(/\/+$/, '')
    : API_URL);

const STORE_KEY = 'forever.tokens';

export class ApiError extends Error {
  constructor(message, { status, code, fieldErrors } = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.fieldErrors = fieldErrors;
  }
}

// Guarded: this module is also imported during server-side rendering (Node has no `localStorage`).
const hasLocalStorage = typeof localStorage !== 'undefined';

let tokens = readTokens();
let onSessionExpired = () => {};
let onAdminForbidden = () => {};
let refreshing = null;

function readTokens() {
  if (!hasLocalStorage) return null;
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
    if (hasLocalStorage) localStorage.setItem(STORE_KEY, JSON.stringify(tokens));
  },
  clear() {
    tokens = null;
    if (hasLocalStorage) localStorage.removeItem(STORE_KEY);
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
  const url = new URL(baseUrl() + path);
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

// Anonymous cart session (NOT a login): an opaque token kept under its own key, separate from the login
// tokens, so the guest cart survives reloads / browser restarts while the server keeps the session alive.
// Read from localStorage on every use so all tabs share the same session. Never touched during SSR.
const GUEST_KEY = 'forever.guestSession';
let onGuestExpired = () => {};
let creatingGuest = null;

export const guestSession = {
  token() {
    if (!hasLocalStorage) return null;
    try {
      return JSON.parse(localStorage.getItem(GUEST_KEY))?.token || null;
    } catch {
      return null;
    }
  },
  has: () => !!guestSession.token(),
  set(res) {
    if (hasLocalStorage) localStorage.setItem(GUEST_KEY, JSON.stringify({ token: res.token, expiresAt: res.expiresAt }));
  },
  clear() {
    if (hasLocalStorage) localStorage.removeItem(GUEST_KEY);
  },
  // The API no longer knows `token`: drop it (unless another tab already replaced it) and tell the app.
  expired(token) {
    if (guestSession.token() === token) guestSession.clear();
    onGuestExpired();
  },
  onExpired(fn) {
    onGuestExpired = fn;
  },
  // Returns the current guest token, starting ONE session (shared by concurrent callers) when there is none.
  async ensure() {
    const existing = guestSession.token();
    if (existing) return existing;
    creatingGuest ??= request('/api/guest-sessions', { method: 'POST', auth: false })
      .then((res) => {
        guestSession.set(res);
        return res.token;
      })
      .finally(() => {
        creatingGuest = null;
      });
    return creatingGuest;
  },
  // Ends the session server-side (its cart is discarded; orders are kept) and forgets it. Best effort: the
  // local token is dropped first, whatever the server says.
  async end() {
    const token = guestSession.token();
    guestSession.clear();
    if (!token) return;
    try {
      await request('/api/guest-sessions/current', { method: 'DELETE', auth: false, guestToken: token });
    } catch {
      // Already expired / unreachable: the session dies on its own once it idles out.
    }
  },
};

// A guest order's access token (returned when it was placed) lives in sessionStorage only: per tab and gone
// when the tab closes, so the next person on a shared device can't reopen the confirmation. Never put it
// in a URL and never log it.
const hasSessionStorage = typeof sessionStorage !== 'undefined';
const accessKey = (orderId) => `forever.orderAccess.${orderId}`;
export const orderAccess = {
  get(orderId) {
    if (!hasSessionStorage) return null;
    try {
      return sessionStorage.getItem(accessKey(orderId));
    } catch {
      return null;
    }
  },
  set(orderId, token) {
    if (!hasSessionStorage || !token) return;
    try {
      sessionStorage.setItem(accessKey(orderId), token);
    } catch {
      // Storage blocked: the confirmation just can't be reopened in this tab.
    }
  },
};

// Requests that may carry the guest cart session (X-Guest-Session). Nothing else ever gets it.
const guestPath = (method, path) =>
  path === '/api/cart' || path.startsWith('/api/cart/') ||
  path === '/api/checkout' || path.startsWith('/api/checkout/') ||
  (method === 'POST' && (path === '/api/orders' || path === '/api/khqr/checkout'));

// `orderAccess`: a guest order's access token, sent as X-Order-Access (and no other identity).
// `guestToken`: send this guest session explicitly (only used to end a session).
async function request(path, { method = 'GET', body, query, auth = true, orderAccess: access, guestToken, retried = false } = {}) {
  const headers = { Accept: 'application/json' };
  // FormData (admin image uploads) must keep the browser-generated multipart boundary.
  const isForm = typeof FormData !== 'undefined' && body instanceof FormData;
  if (body !== undefined && !isForm) headers['Content-Type'] = 'application/json';
  // A request carries at most ONE identity: the login token, else (cart/checkout only) the guest session.
  // The API refuses both together (400 AMBIGUOUS_IDENTITY).
  let sentGuest = null;
  if (access) {
    headers['X-Order-Access'] = access;
  } else if (guestToken) {
    headers['X-Guest-Session'] = guestToken;
  } else if (auth && tokens?.accessToken) {
    headers.Authorization = `Bearer ${tokens.accessToken}`;
  } else if (auth && guestPath(method, path)) {
    sentGuest = guestSession.token();
    if (sentGuest) headers['X-Guest-Session'] = sentGuest;
  }

  let res;
  try {
    res = await fetch(buildUrl(path, query), {
      method,
      headers,
      body: body === undefined ? undefined : isForm ? body : JSON.stringify(body),
    });
  } catch {
    throw new ApiError(`Cannot reach the server (${baseUrl()}). Is the API running?`, { code: 'NETWORK' });
  }

  // Only a request that actually carried the login token may trigger a token refresh (never a guest call).
  if (res.status === 401 && headers.Authorization && !retried && tokens?.refreshToken && (await refreshTokens())) {
    return request(path, { method, body, query, auth, retried: true });
  }
  if (res.status === 403 && path.startsWith('/api/admin')) onAdminForbidden();
  if (res.status === 204) return null;

  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    // Non-JSON body (e.g. a proxy's HTML error page): fall back to the status-based message below.
  }
  if (!res.ok) {
    // The guest session is unknown or expired: forget it. A new one only starts when the shopper next adds
    // something to the cart.
    if (res.status === 401 && sentGuest) guestSession.expired(sentGuest);
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
  addToCart: (productId, size, quantity = 1) => post('/api/cart/items', { productId, size, quantity }),
  setCartQuantity: (productId, size, quantity) =>
    request('/api/cart/items', { method: 'PUT', body: { productId, size, quantity } }),
  // orders
  placeOrder: (b) => post('/api/orders', b),
  khqrCheckout: (b) => post('/api/khqr/checkout', b),
  // Resolve { paid, status } where status is PENDING, PAID or CANCELLED.
  verifyKhqr: (orderId) => post(`/api/khqr/${orderId}/verify`),
  cancelKhqr: (orderId) => post(`/api/khqr/${orderId}/cancel`),
  checkoutOptions: () => request('/api/checkout/options'),
  // Preview a coupon before ordering: resolves { code, description, discountType, discount, summary } or throws with the reason.
  checkCoupon: (code, subtotal) => post('/api/checkout/coupon', { code, subtotal }),
  // A guest's own order, opened with the access token returned when it was placed (no other identity).
  guestOrder: (id, access) => request(`/api/guest-orders/${id}`, { orderAccess: access }),
  guestVerifyKhqr: (id, access) => request(`/api/guest-orders/${id}/khqr/verify`, { method: 'POST', orderAccess: access }),
  guestCancelKhqr: (id, access) => request(`/api/guest-orders/${id}/khqr/cancel`, { method: 'POST', orderAccess: access }),
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
  adminDeleteProduct: (id) => request(`/api/admin/products/${id}`, { method: 'DELETE' }),
  adminOrders: (query) => request('/api/admin/orders', { query }),
  // reason is required for CANCELLED; it is emailed to the customer.
  adminUpdateOrderStatus: (id, status, reason) =>
    request(`/api/admin/orders/${id}/status`, { method: 'PATCH', body: { status, reason } }),
  // Resolves { items: [{ id, type, title, message, link, read, createdAt }], unreadCount }.
  adminNotifications: (query) => request('/api/admin/notifications', { query }),
  adminReadNotification: (id) => post(`/api/admin/notifications/${id}/read`),
  adminReadAllNotifications: () => post('/api/admin/notifications/read-all'),
  adminInventory: () => request('/api/admin/inventory'),
  adminSetStock: (productId, size, stock) => request(`/api/admin/inventory/${productId}/${size}`, { method: 'PUT', body: { stock } }),
  adminCategories: () => request('/api/admin/categories'),
  adminAddCategory: (name) => post('/api/admin/categories', { name }),
  adminRenameCategory: (id, name) => request(`/api/admin/categories/${id}`, { method: 'PUT', body: { name } }),
  // productIds omitted = move every product in the category. Resolves { moved, target }.
  // targetSubCategoryId omitted = products keep their sub-category. Resolves { moved, target, subCategory }.
  adminMoveCategoryProducts: (id, { targetId, targetSubCategoryId, productIds }) =>
    post(`/api/admin/categories/${id}/move-products`, { targetId, targetSubCategoryId, productIds }),
  // moveTo is required while the category still has products.
  // moveToSub (a sub-category of moveTo) puts all moved products in it; omitted = they keep their own.
  adminDeleteCategory: (id, moveTo, moveToSub) =>
    request(`/api/admin/categories/${id}`, { method: 'DELETE', query: { moveTo, moveToSub } }),
  // Sub-categories belong to one category. Resolves [{ id, categoryId, name, productCount }].
  adminSubCategories: (categoryId) => request(`/api/admin/categories/${categoryId}/sub-categories`),
  adminAddSubCategory: (categoryId, name) => post(`/api/admin/categories/${categoryId}/sub-categories`, { name }),
  adminRenameSubCategory: (id, name) => request(`/api/admin/sub-categories/${id}`, { method: 'PUT', body: { name } }),
  // moveTo (another sub-category of the same category) is required while it still has products.
  adminDeleteSubCategory: (id, moveTo) => request(`/api/admin/sub-categories/${id}`, { method: 'DELETE', query: { moveTo } }),
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
