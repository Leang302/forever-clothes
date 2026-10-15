#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$ROOT_DIR/.run"
API_DIR="$ROOT_DIR/Forever-API"

signal_process_tree() {
  local signal="$1"
  local parent_pid="$2"
  local child_pid

  while read -r child_pid; do
    [[ -n "$child_pid" ]] || continue
    signal_process_tree "$signal" "$child_pid"
  done < <(pgrep -P "$parent_pid" 2>/dev/null || true)

  kill "-$signal" "$parent_pid" 2>/dev/null || true
}

stop_process() {
  local name="$1"
  local pid_file="$2"

  if [[ ! -f "$pid_file" ]]; then
    echo "$name is not recorded as running."
    return
  fi

  local pid
  pid="$(<"$pid_file")"

  if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
    echo "Stopping $name (PID $pid)..."
    signal_process_tree TERM "$pid"

    # Give the development server a moment to shut down cleanly.
    local attempt
    for attempt in 1 2 3 4 5; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done

    if kill -0 "$pid" 2>/dev/null; then
      echo "$name did not stop cleanly; forcing it to stop."
      signal_process_tree KILL "$pid"
    fi
  else
    echo "$name is already stopped."
  fi

  rm -f "$pid_file"
}

stop_process "API" "$RUNTIME_DIR/api.pid"
stop_process "frontend" "$RUNTIME_DIR/frontend.pid"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "Stopping Postgres, MinIO, and Mailpit..."
  docker compose -f "$API_DIR/docker-compose.yml" stop
else
  echo "Docker is unavailable; its services were not stopped." >&2
fi

echo "Everything is stopped. Docker containers and data were kept."
