# Deploying Forever

Three deliverables: the **Spring Boot API**, the **React storefront + admin** (server-side rendered by a small
Node server), and the **Flutter** app. The API and website deploy together with one Docker Compose stack.

## 1. Website + API on one server (recommended)

Needs: a Linux VPS with Docker, two DNS names pointing at it (e.g. `shop.example.com`, `api.shop.example.com`),
ports 80 and 443 open. Caddy issues the HTTPS certificates automatically.

```bash
git clone https://github.com/Leang302/forever-clothes.git && cd forever-clothes
cp deploy/.env.example deploy/.env      # fill in every value — see the comments in the file
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d --build
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env logs -f api   # wait for "Started ForeverApiApplication"
```

On the first start the API runs the Flyway migrations, creates the MinIO bucket, seeds the admin account from
`ADMIN_EMAIL`/`ADMIN_PASSWORD`, and imports the catalogue.

| What | URL |
|---|---|
| Customer website | `https://SITE_DOMAIN` |
| Admin panel | `https://SITE_DOMAIN/admin` (log in with `ADMIN_EMAIL` / `ADMIN_PASSWORD`) |
| API / Swagger | `https://API_DOMAIN/swagger-ui.html` |

### Verify the deployment

```bash
curl -s https://API_DOMAIN/actuator/health                    # {"status":"UP",...}
curl -s https://SITE_DOMAIN/ | grep -o '<title>[^<]*'           # server-rendered HTML
curl -s https://SITE_DOMAIN/product/<id> | grep -o 'og:title[^>]*'   # share-preview tags present
```

Then, in a private browser window: add to cart as a guest → checkout → KHQR → pay a small amount with a Bakong
app (real money — use your own test amount) → the order shows as paid in `/admin` order history.

### Configuration reference

| Variable | Where | Purpose |
|---|---|---|
| `DB_PASSWORD`, `JWT_SECRET`, `MINIO_*` | API | Secrets. Generate fresh values; never reuse the dev ones. |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | API | Seeded admin. The dev default `Admin@12345` must not be used in production. |
| `CORS_ALLOWED_ORIGINS` | API | Set by the compose file to `https://SITE_DOMAIN`. |
| `PUBLIC_API_URL` | API | Set by the compose file to `https://API_DOMAIN`; image URLs use it, so server-rendered pages and share previews get reachable images. |
| `MAIL_*` | API | SMTP for OTP and order e-mails. |
| `KHQR_ACCOUNT_ID`, `KHQR_API_TOKEN`, `KHQR_MERCHANT_*` | API | Real Bakong merchant account + Open API token. |
| `VITE_API_URL` (build arg) | Web | API URL the browser calls, baked into the bundle: `https://API_DOMAIN`. |
| `SSR_API_URL` | Web | API URL the SSR server calls; `http://api:8989` inside the stack. |
| `PUBLIC_SITE_URL` | Web | Absolute site URL used in share links and Open Graph tags. |

### Updating / backups

```bash
git pull && docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d --build
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec postgres pg_dump -U forever forever > backup.sql
```

## 2. Flutter app

Point the app at the deployed API and website at build time:

```bash
cd Forever-App
flutter build apk --release \
  --dart-define=API_BASE_URL=https://API_DOMAIN \
  --dart-define=WEB_BASE_URL=https://SITE_DOMAIN
# iOS: flutter build ipa --release (same --dart-define flags; needs an Apple signing setup)
```

`WEB_BASE_URL` is what product share links point to; without it they point at the local dev website, which
other people can't open.

## 3. Local development

See `DEMO_FLOW.md` (`./run.sh` / `./stop.sh` / `./reset.sh`). To exercise KHQR locally without real money, start
the dev-only fake Bakong and point the API at it — see `Forever-API/dev/fake-bakong.mjs`.
