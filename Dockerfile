# syntax=docker/dockerfile:1

############################
# 1) Build frontend
############################
FROM node:20-bookworm-slim AS frontend-builder

WORKDIR /app/stock_frontend

COPY stock_frontend/package*.json ./
RUN npm ci

COPY stock_frontend/ ./
RUN npm run build


############################
# 2) Runtime image
############################
FROM python:3.11-slim-bookworm

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV FLASK_ENV=production
ENV PORT=80

WORKDIR /app

# Install system packages:
# - nginx: serve frontend and reverse proxy API
# - supervisor: run nginx + flask together
# - ca-certificates/tzdata: network/time stability
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        supervisor \
        ca-certificates \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /app/requirements.txt \
    && pip install --no-cache-dir gunicorn

# Copy backend source
COPY . /app

# Copy frontend dist from builder.
# Vite usually builds into stock_frontend/dist.
COPY --from=frontend-builder /app/stock_frontend/dist /usr/share/nginx/html

# Copy nginx and start script
COPY nginx.conf /etc/nginx/nginx.conf
COPY docker/start.sh /app/docker/start.sh

RUN chmod +x /app/docker/start.sh \
    && mkdir -p /app/data /var/log/supervisor /run/nginx

EXPOSE 80

CMD ["/app/docker/start.sh"]
