# Forever Store Demo Flow

This guide provides a simple presentation flow for demonstrating the Forever storefront, admin panel, backend API, and supporting services.

## 1. Start the project

From the project root:

```bash
./run.sh
```

Available services:

| Service | URL |
|---|---|
| Storefront | http://localhost:5173 |
| Admin panel | http://localhost:5173/admin |
| Swagger UI | http://localhost:8989/swagger-ui.html |
| API health | http://localhost:8989/actuator/health |
| Mailpit | http://localhost:8025 |
| MinIO console | http://localhost:9001 |

## 2. Admin login

Use the seeded development administrator:

```text
Email: admin@forever.com
Password: Admin@12345
```

Change this password before using the application outside local development.

## 3. Admin demonstration

1. Sign in with the admin account.
2. Open **Admin panel** from the profile menu.
3. Show the dashboard statistics:
   - Revenue
   - Total orders
   - Orders waiting for fulfilment
   - Active and hidden products
   - Customer count
   - Revenue for the last 30 days
   - Top-selling products
4. Open **Products** and demonstrate:
   - Product search and category filtering
   - Creating or editing a product
   - Uploading product images
   - Hiding and restoring a product
5. Open **Orders** and update an order through its delivery statuses.
6. Open **Management** and demonstrate:
   - Inventory by product size
   - Low-stock warnings
   - Customer order history
   - Product-category management
   - Coupon creation and deletion

## 4. Customer account demonstration

1. Register a new customer account.
2. Open Mailpit and copy the verification code from the email.
3. Verify the account and sign in.
4. Open **My profile** and demonstrate:
   - Editing the customer name and phone number
   - Changing the password
5. Add and remove products from the wishlist.
6. Open the dedicated **Wishlist** page from the profile menu.

## 5. Shopping demonstration

1. Browse the home page and collection.
2. Search or filter products.
3. Open a product and select a size.
4. Add the product to the cart.
5. Change the cart quantity and review the totals.
6. Continue to checkout.
7. Enter a shipping address or select a previously saved address.
8. Optionally save the new address for future orders.
9. Select standard or express delivery.
10. Optionally enter an active coupon code created in the admin panel.

## 6. Cash on Delivery flow

1. Select **Cash on Delivery**.
2. Place the order.
3. Show the order-confirmation page.
4. Open **Orders** and view the order details and tracking timeline.
5. In the admin panel, advance the order through packing, shipping, delivery, and completion.

Inventory is deducted when the order is created. Cancelling an eligible order restores its inventory.

## 7. ABA PayWay sandbox flow

The checkout offers **ABA PayWay** as the second payment option. Before demonstrating it, configure fresh sandbox credentials in `Forever-API/.env.local`:

```properties
PAYWAY_MERCHANT_ID=your_sandbox_merchant_id
PAYWAY_API_KEY=your_new_sandbox_api_key
PAYWAY_CALLBACK_URL=https://your-whitelisted-domain/api/payway/callback
PAYWAY_SUCCESS_URL=http://localhost:5173/order
PAYWAY_CANCEL_URL=http://localhost:5173/place-order
```

Do not commit `.env.local`, API keys, or RSA private keys.

PayWay requires the callback domain or IP address to be whitelisted. A public HTTPS URL or tunnel approved in the PayWay merchant settings is required; PayWay cannot send a callback to `localhost`.

Demo steps:

1. Select **ABA PayWay** during checkout.
2. Click **Continue to ABA PayWay**.
3. The backend creates a pending order and signs the hosted checkout request.
4. The browser opens ABA PayWay's sandbox checkout.
5. Complete the sandbox payment.
6. PayWay sends a signed callback to the backend.
7. The backend verifies the callback, marks the order as paid, and changes its status from `PAYMENT_PENDING` to `ORDER_PLACED`.
8. The customer receives an order-confirmation email.

If the sandbox credentials or callback URL are not configured, the API returns `PAYWAY_NOT_CONFIGURED` instead of exposing secrets or creating an unsigned request.

## 8. Email demonstration

Open Mailpit at http://localhost:8025 to show:

- Account-verification OTP emails
- Password-reset OTP emails
- Order-confirmation emails

## 9. API demonstration

Open Swagger UI at http://localhost:8989/swagger-ui.html.

1. Use the login endpoint to obtain an access token.
2. Click **Authorize** and enter the bearer token.
3. Demonstrate product, profile, wishlist, address, cart, order, and admin endpoints.
4. Do not display refresh tokens, API keys, or private keys during the presentation.

## 10. Stop the project

Press `Ctrl+C` in the terminal running `run.sh` to stop the frontend and backend.

To stop the supporting Docker services as well:

```bash
./stop.sh
```

Docker volumes are preserved, so database and MinIO data remain available for the next demonstration.
