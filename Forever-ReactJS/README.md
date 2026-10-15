# Fashion-E-Commerce-Project
Project base learning React

# React + Vite

This template provides a minimal setup to get React working in Vite with HMR and some ESLint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react/README.md) uses [Babel](https://babeljs.io/) for Fast Refresh
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react-swc) uses [SWC](https://swc.rs/) for Fast Refresh

## Running against the Forever API

The web app now talks to the Spring Boot API (`../Forever-API`) for products, login with e-mail OTP, cart and orders.

```bash
cp .env.example .env.local     # VITE_API_URL=http://localhost:8989 (default)
npm install
npm run dev
```

Cart, checkout and orders require an account: sign up, enter the code from the e-mail (Mailpit at http://localhost:8025 in dev).

## Admin panel

Signed-in users with the `ADMIN` role get an **Admin panel** button in the profile menu (top right; in the menu on phones),
which opens `/admin`: dashboard (revenue, orders by status, recent orders), products (search, show/hide, create and edit with
image upload), and orders (filter by status, move through the fulfilment steps, see items and delivery address).

* Everyone else - guests and customers - is silently sent back to the home page when they open an `/admin` URL, and the button
  is not rendered for them. The API enforces the role on every `/api/admin/**` call as well (a 403 also sends the user home).
* Dev admin account: `admin@forever.com` / `Admin@12345` (seeded by the API; change it for anything beyond local development).
