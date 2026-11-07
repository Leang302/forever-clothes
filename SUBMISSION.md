# Final Project Submission Kit

Fill in the `<…>` placeholders only with things that actually exist and that you have checked yourself.

## 1. Deliverables checklist

| # | Deliverable | Status | How to confirm |
|---|---|---|---|
| S01 | Live customer website URL | ☐ | Deploy per `DEPLOYMENT.md`; open it in a private window on mobile data. |
| S02 | Admin URL + working login | ☐ | `https://<SITE_DOMAIN>/admin`, log in with the production admin account. |
| S03 | GitHub repository | ☐ | `https://github.com/Leang302/forever-clothes` — open it while logged out (must be public, or the instructor added). Push the final commit first. |
| S04 | Walkthrough video | ☐ | Recorded per the shot list below, uploaded (YouTube unlisted / Google Drive "anyone with link"), link tested logged out. |
| S05 | Telegram Topic post | ☐ | Posted in the correct topic, in the format your instructor specified. |

## 2. Video shot list (covers every assignment requirement)

Record on the **deployed** site. Suggested length 6–10 minutes.

1. **Home page** — product grid: name, price, description, thumbnail; *View details*; *Add to cart* straight from a card (pick size + quantity).
2. **Product detail** — images, full description, price, **stock status** (an in-stock size, a low-stock "Only N left", an out-of-stock size that can't be selected), **quantity selector**, *Add to cart*; click **Facebook** and **Telegram** share and show the link preview.
3. **Cart** — items, unit price, quantity, line subtotal, total; change a quantity; remove an item; *Checkout*.
4. **Guest checkout** — in a private window with no account: full name, email, phone, shipping address (show a validation message once).
5. **KHQR** — the code appears with the amount; show the order is *awaiting payment*; scan and pay with a Bakong app; status turns *paid*.
6. **Order confirmation** — success message, order ID, customer details, total, items.
7. **Admin** — log in at `/admin`; product table (ID, name, price, stock, status); **add** a product (with an image URL, stock, status); **edit** it; **delete** it.
8. **Admin order history** — the order you just placed: ID, customer name, phone, total, date; open its details: products, quantities, subtotals, shipping address.
9. *(Optional)* **SSR proof** — `view-source:` on a product page showing the product name/price in the raw HTML.
10. *(Optional)* **Mobile app** — the same guest purchase in the Flutter app.

## 3. Telegram Topic message — TEMPLATE

> Replace with your instructor's required format if it differs. Do not post until every link opens for someone else.

```
Final Project — E-Commerce Website (Forever)
Student: <full name> (<student ID>)
Group: <class/group>

🌐 Website: https://<SITE_DOMAIN>
🛠 Admin: https://<SITE_DOMAIN>/admin
   Email: <admin email for grading>
   Password: <password for grading — create a separate grading account if you prefer>
💻 GitHub: https://github.com/Leang302/forever-clothes
🎬 Video: <video link>

Stack: React (SSR, Node/Express) · Spring Boot · PostgreSQL · KHQR (Bakong) · Flutter (mobile)
```
