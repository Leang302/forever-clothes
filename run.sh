#!/usr/bin/env bash

set -eu

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$ROOT_DIR/Forever-API"
FRONTEND_DIR="$ROOT_DIR/Forever-ReactJS"
RUNTIME_DIR="$ROOT_DIR/.run"

for command_name in docker java npm; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Error: '$command_name' is required but was not found." >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "Error: Docker is not running. Start Docker Desktop and try again." >&2
  exit 1
fi

if [[ ! -f "$API_DIR/.env.local" ]]; then
  echo "Error: $API_DIR/.env.local is missing. Add the API secrets before starting." >&2
  exit 1
fi

echo "Starting Postgres, MinIO, and Mailpit..."
docker compose -f "$API_DIR/docker-compose.yml" up -d --wait --wait-timeout 120

if [[ ! -d "$FRONTEND_DIR/node_modules" ]]; then
  echo "Installing frontend dependencies..."
  (cd "$FRONTEND_DIR" && npm install)
fi

api_pid=""
frontend_pid=""
mkdir -p "$RUNTIME_DIR"

cleanup() {
  trap - INT TERM EXIT
  echo
  echo "Stopping API and frontend..."
  [[ -n "$api_pid" ]] && kill "$api_pid" 2>/dev/null || true
  [[ -n "$frontend_pid" ]] && kill "$frontend_pid" 2>/dev/null || true
  [[ -n "$api_pid" ]] && wait "$api_pid" 2>/dev/null || true
  [[ -n "$frontend_pid" ]] && wait "$frontend_pid" 2>/dev/null || true
  rm -f "$RUNTIME_DIR/api.pid" "$RUNTIME_DIR/frontend.pid"
  echo "Development servers stopped. Docker services are still running."
  echo "Stop them without removing them with: ./stop.sh"
}

trap cleanup INT TERM EXIT

echo "Starting API..."
(cd "$API_DIR" && exec ./gradlew bootRun) &
api_pid=$!
echo "$api_pid" > "$RUNTIME_DIR/api.pid"

echo "Starting frontend..."
(cd "$FRONTEND_DIR" && exec npm run dev) &
frontend_pid=$!
echo "$frontend_pid" > "$RUNTIME_DIR/frontend.pid"

echo
echo "Frontend:  http://localhost:5173"
echo "API docs: http://localhost:8989/swagger-ui.html"
echo "Mailpit:   http://localhost:8025"
echo "Press Ctrl+C to stop the API and frontend."
echo

exit_code=0
while kill -0 "$api_pid" 2>/dev/null && kill -0 "$frontend_pid" 2>/dev/null; do
  sleep 1
done

if ! kill -0 "$api_pid" 2>/dev/null; then
  wait "$api_pid" || exit_code=$?
  echo "API stopped unexpectedly (exit code $exit_code)." >&2
else
  wait "$frontend_pid" || exit_code=$?
  echo "Frontend stopped unexpectedly (exit code $exit_code)." >&2
fi

exit "$exit_code"
