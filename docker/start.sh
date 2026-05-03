#!/usr/bin/env bash
set -e

cd /app

echo "======================================"
echo "Starting a-stock-trading"
echo "======================================"
echo "Python: $(python --version)"
echo "Working directory: $(pwd)"
echo "======================================"

# Ensure writable data directory exists
mkdir -p /app/data

# Optional: if the app later supports DATABASE_URL, keep it available
export DATABASE_URL="${DATABASE_URL:-sqlite:////app/data/a_stock_trading.db}"

# Start Flask backend by gunicorn.
# api_server.py exposes variable: app = Flask(__name__)
gunicorn \
  --bind 127.0.0.1:5000 \
  --workers "${GUNICORN_WORKERS:-2}" \
  --threads "${GUNICORN_THREADS:-4}" \
  --timeout "${GUNICORN_TIMEOUT:-300}" \
  --access-logfile - \
  --error-logfile - \
  api_server:app &

BACKEND_PID=$!

echo "Backend started with PID: ${BACKEND_PID}"

# Start nginx in foreground
nginx -g "daemon off;" &

NGINX_PID=$!

echo "Nginx started with PID: ${NGINX_PID}"

# If either process exits, stop the container
wait -n "${BACKEND_PID}" "${NGINX_PID}"

echo "One process exited. Stopping container..."
kill "${BACKEND_PID}" "${NGINX_PID}" 2>/dev/null || true
wait
