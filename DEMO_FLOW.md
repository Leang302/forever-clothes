# Forever Store Demo Flow

This guide provides a presentation flow for demonstrating the Forever admin panel first, then the customer storefront, backend API, and supporting services.

## 1. Before the demo

### Reset to a clean state

To start from the original seeded data (no orders, customers, coupons, or demo edits), run from the project root:

```bash
./reset.sh
```

This stops the app, wipes the database and MinIO uploads, and clears the Mailpit inbox. The next start re-creates the admin account and the 52 seeded products with their images, categories, and stock (20 per size).

### Start the project

```bash
./run.sh
```

Wait until the API log shows `Seeded 52 products` after a reset.

Available services:

| Service | URL |
|---|---|
| Storefront | http://localhost:5173 |
| Admin panel | http://localhost:5173/admin |
| Swagger UI | http://localhost:8989/swagger-ui.html |
| API health | http://localhost:8989/actuator/health |
| Mailpit | http://localhost:8025 |
| MinIO console | http://localhost:9001 |

### Prepare

- Open two browser windows: a normal one for the admin and a private one for the customer, so both can stay signed in.
- Have an email inbox ready for the customer account. With the current `.env.local`, emails are sent through Gmail, so use a real address you can open during the demo. Mailpit only receives emails when `MAIL_HOST` is not set.
- As a backup, OTP codes are also printed in the `run.sh` terminal while `OTP_LOG_CODE=true`.

## 2. Admin demonstration

### Sign in

Use the seeded development administrator:

```text
Email: admin@forever.com
Password: Admin@12345
```

Change this password before using the application outside local development.

1. Sign in with the admin account.
2. Open **Admin panel** from the profile menu.

### Dashboard

Show the dashboard statistics. After a reset, revenue, orders, and customers are zero; point out that they will update after the customer demo.

- Revenue
- Total orders
- Orders waiting for fulfilment
- Active and hidden products
- Customer count
- Revenue for the last 30 days
- Top-selling products

### Products

1. Search products and filter by category.
2. Create a new product and upload its images.
3. Edit an existing product.
4. Hide a product, then restore it.

### Management

1. **Inventory** — show stock by product size and the low-stock warnings. Lower one size to 5 or less to show a warning.
2. **Categories** — add and remove a product category.
3. **Coupons** — create a coupon (for example `DEMO10`, 10% off). The customer will use it at checkout.

## 3. Customer demonstration

Switch to the private browser window.

### Account

1. Register a new customer account.
2. Open the inbox and copy the verification code (or take it from the `run.sh` terminal).
3. Verify the account and sign in.
4. Open **My profile** and demonstrate:
   - Editing the customer name and phone number
   - Changing the password

### Browsing and wishlist

1. Browse the home page and collection.
2. Search or filter products. The product created in the admin demo is now visible; the hidden product is not.
3. Add and remove products from the wishlist.
4. Open the **Wishlist** page from the profile menu.

### Cart and checkout

1. Open a product and select a size.
2. Add the product to the cart.
3. Change the cart quantity and review the totals.
4. Continue to checkout.
5. Enter a shipping address and save it for future orders.
6. Select standard or express delivery.
7. Enter the coupon created in the admin demo and show the discount.

### Cash on Delivery

1. Select **Cash on Delivery**.
2. Place the order.
3. Show the order-confirmation page and the order-confirmation email.
4. Open **Orders** and view the order details and tracking timeline.

Inventory is deducted when the order is created. Cancelling an eligible order restores its inventory.

## 4. Back to the admin panel

Switch to the admin window to close the loop.

1. Open **Orders**, find the customer's order, and advance it one step at a time: Order placed → Shipped → Delivered. Statuses can only move forward one step, cancelling is only allowed before shipping, and Delivered is final. A Cash on Delivery order is marked paid when it is delivered.
2. In the customer window, refresh **Orders** to show the updated tracking timeline.
3. Back in the admin panel, show that:
   - The dashboard now shows the revenue, order, and customer count.
   - **Inventory** shows the reduced stock for the ordered size.
   - **Customers** shows the new customer and their order history.

## 5. KHQR (Bakong) payment flow (optional)

The checkout offers **KHQR** as the second payment option. The customer scans the code with Bakong or any Cambodian banking app (ABA, ACLEDA, Wing…). Before demonstrating it, configure `Forever-API/.env.local`:

```properties
KHQR_ACCOUNT_ID=your_bakong_account@bank
KHQR_MERCHANT_NAME=Forever
KHQR_MERCHANT_CITY=Phnom Penh
KHQR_API_TOKEN=your_bakong_open_api_token
```

- `KHQR_ACCOUNT_ID` is the Bakong account that receives the money (shown in the Bakong app profile, e.g. `name@aclb`).
- `KHQR_API_TOKEN` comes from registering at https://api-bakong.nbc.gov.kh/register. It expires every 90 days; renew it at the same site.
- The Bakong Open API only accepts requests from Cambodian IP addresses, so the API must run in Cambodia (or behind a Cambodian proxy).
- Do not commit `.env.local` or the API token.

Demo steps:

1. Select **KHQR** during checkout and click **Pay with KHQR**.
2. The backend creates a `PAYMENT_PENDING` order and returns a dynamic KHQR for the exact total, valid for 10 minutes.
3. Scan the code with a banking app and pay (a small total such as $0.01 keeps the demo cheap).
4. Bakong has no callback, so the client asks the backend every 3 seconds; the backend looks the payment up by the QR's MD5 (`check_transaction_by_md5`).
5. Once it is found, the order is marked paid and moves to `ORDER_PLACED`, and the customer receives the confirmation email.
6. Cancelling, or letting the code expire, cancels the order and puts the items back in the cart, unless Bakong shows the payment already went through.

If the account ID or token is missing, the API returns `KHQR_NOT_CONFIGURED`.

## 6. API demonstration (optional)

Open Swagger UI at http://localhost:8989/swagger-ui.html.

1. Use the login endpoint to obtain an access token.
2. Click **Authorize** and enter the bearer token.
3. Demonstrate product, profile, wishlist, address, cart, order, and admin endpoints.
4. Do not display refresh tokens, API keys, or private keys during the presentation.

## 7. After the demo

Press `Ctrl+C` in the terminal running `run.sh` to stop the frontend and backend.

To stop the supporting Docker services as well, keeping all data:

```bash
./stop.sh
```

To prepare for the next demonstration, run `./reset.sh` to return to the original seeded data.
