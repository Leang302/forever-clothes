#!/usr/bin/env bash
# Resets the backend to a fresh-install state for a clean demo: wipes the database and MinIO uploads.
# The next ./run.sh re-runs the migrations and the seeder (admin account, catalogue, images, stock, categories).

set -eu

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/Forever-API"
COMPOSE=(docker compose -f "$API_DIR/docker-compose.yml")

if ! docker info >/dev/null 2>&1; then
  echo "Error: Docker is not running. Start Docker Desktop and try again." >&2
  exit 1
fi

if [[ "${1:-}" != "-y" ]]; then
  echo "This deletes all orders, customers, carts, coupons, uploaded images and product edits."
  echo "The admin account and the seeded catalogue come back on the next ./run.sh."
  read -r -p "Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
fi

# The API must not be running while its database disappears underneath it.
"$ROOT_DIR/stop.sh"

echo "Resetting the database..."
"${COMPOSE[@]}" up -d --wait --wait-timeout 120 postgres
"${COMPOSE[@]}" exec -T postgres psql -q -v ON_ERROR_STOP=1 -U forever -d forever \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

echo "Resetting MinIO storage..."
"${COMPOSE[@]}" rm -fs minio
project="$("${COMPOSE[@]}" config | awk '/^name:/ { print $2; exit }')"
docker volume rm -f "${project}_minio-data" >/dev/null
"${COMPOSE[@]}" up -d --wait --wait-timeout 120 minio

echo "Clearing Mailpit inbox..."
"${COMPOSE[@]}" up -d mailpit >/dev/null
curl -fsS -X DELETE http://localhost:8025/api/v1/messages >/dev/null 2>&1 || true

echo
echo "Backend reset. Start the app with ./run.sh to reseed the demo data."
