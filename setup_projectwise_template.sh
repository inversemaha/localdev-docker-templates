#!/bin/bash
set -e

# ------------------------------
# VARIABLES
# ------------------------------
BASE_DIR="/media/bot/INT-LOCAL"
TEMPLATE_NAME="docker-dev-workspace"
TEMPLATE_DIR="$BASE_DIR/$TEMPLATE_NAME"

echo "🚀 Creating project-wise template at $TEMPLATE_DIR"

# ------------------------------
# CREATE TEMPLATE FOLDER
# ------------------------------
mkdir -p "$TEMPLATE_DIR"
cd "$TEMPLATE_DIR"

# Subfolders
mkdir -p projects/laravel projects/fastapi projects/react
mkdir -p docker/traefik

touch README.md .env.example

# ------------------------------
# README & ENV
# ------------------------------
cat <<'EOF' > README.md
# Engineering Dev Template
- Laravel / PHP (Nginx, PHP-FPM, MySQL, Redis, Supervisor)
- FastAPI / Python (Postgres, MongoDB, ML libs)
- React / Node
- Traefik for local domains
EOF

cat <<'EOF' > .env.example
# Project Ports
LARAVEL_PORT=8080
FASTAPI_PORT=8000
REACT_PORT=5173
MYSQL_PORT=3307
POSTGRES_PORT=5432
MONGO_PORT=27017
EOF

# ------------------------------
# LARAVEL TEMPLATE (NGINX + PHP-FPM)
# ------------------------------
LARAVEL_DIR="$TEMPLATE_DIR/projects/laravel"
mkdir -p "$LARAVEL_DIR/nginx"

cat <<'EOF' > $LARAVEL_DIR/Dockerfile
FROM php:8.3-fpm
RUN apt-get update && apt-get install -y git unzip libzip-dev libpng-dev zip libonig-dev libxml2-dev supervisor \
    && docker-php-ext-install pdo pdo_mysql zip gd \
    && pecl install redis xdebug \
    && docker-php-ext-enable redis xdebug
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
WORKDIR /var/www/html
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["supervisord", "-n"]
EOF

cat <<'EOF' > $LARAVEL_DIR/supervisord.conf
[supervisord]
nodaemon=true

[program:php-fpm]
command=/usr/local/sbin/php-fpm -F
autostart=true
autorestart=true

[program:queue-worker]
command=php /var/www/html/artisan queue:work --sleep=3 --tries=3
autostart=false
autorestart=true
stdout_logfile=/var/www/html/storage/logs/worker.log
stderr_logfile=/var/www/html/storage/logs/worker_error.log
EOF

cat <<'EOF' > $LARAVEL_DIR/nginx/default.conf
server {
    listen 80;
    server_name localhost;
    root /var/www/html/public;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass laravel_app:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

cat <<'EOF' > $LARAVEL_DIR/docker-compose.yml
version: "3.9"
services:
  nginx:
    image: nginx:alpine
    container_name: laravel_nginx
    volumes:
      - ./:/var/www/html
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
    ports:
      - "${LARAVEL_PORT}:80"
    depends_on:
      - laravel
    networks:
      - laravel_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.laravel.rule=Host(`laravel.local`)"
      - "traefik.http.services.laravel.loadbalancer.server.port=80"

  laravel:
    build: .
    container_name: laravel_app
    volumes:
      - ./:/var/www/html
    networks:
      - laravel_net

  mysql:
    image: mysql:8.0
    container_name: laravel_mysql
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: app
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - laravel_net

  redis:
    image: redis:7-alpine
    container_name: laravel_redis
    networks:
      - laravel_net

networks:
  laravel_net:
  traefik_net:
    external: true

volumes:
  mysql_data:
EOF

# ------------------------------
# FASTAPI TEMPLATE
# ------------------------------
FASTAPI_DIR="$TEMPLATE_DIR/projects/fastapi"
mkdir -p "$FASTAPI_DIR"

cat <<'EOF' > $FASTAPI_DIR/Dockerfile
FROM python:3.11
WORKDIR /app
RUN pip install --no-cache-dir fastapi uvicorn[standard] sqlalchemy psycopg2-binary \
    pandas numpy matplotlib scikit-learn jupyter torch transformers
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat <<'EOF' > $FASTAPI_DIR/docker-compose.yml
version: "3.9"
services:
  fastapi:
    build: .
    container_name: fastapi_app
    volumes:
      - ./:/app
    ports:
      - "${FASTAPI_PORT}:8000"
    networks:
      - fastapi_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.fastapi.rule=Host(`fastapi.local`)"
      - "traefik.http.services.fastapi.loadbalancer.server.port=8000"

  postgres:
    image: postgres:16
    container_name: fastapi_postgres
    environment:
      POSTGRES_PASSWORD: root
    volumes:
      - pg_data:/var/lib/postgresql/data
    networks:
      - fastapi_net

  mongo:
    image: mongo:7
    container_name: fastapi_mongo
    volumes:
      - mongo_data:/data/db
    networks:
      - fastapi_net

networks:
  fastapi_net:
  traefik_net:
    external: true

volumes:
  pg_data:
  mongo_data:
EOF

# ------------------------------
# REACT TEMPLATE
# ------------------------------
REACT_DIR="$TEMPLATE_DIR/projects/react"
mkdir -p "$REACT_DIR"

cat <<'EOF' > $REACT_DIR/Dockerfile
FROM node:20
WORKDIR /app
COPY package*.json ./
RUN npm install
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host"]
EOF

cat <<'EOF' > $REACT_DIR/docker-compose.yml
version: "3.9"
services:
  react:
    build: .
    container_name: react_app
    volumes:
      - ./:/app
    ports:
      - "${REACT_PORT}:5173"
    networks:
      - react_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.react.rule=Host(`react.local`)"
      - "traefik.http.services.react.loadbalancer.server.port=5173"

networks:
  react_net:
  traefik_net:
    external: true
EOF

# ------------------------------
# TRAEFIK TEMPLATE
# ------------------------------
TRAEFIK_DIR="$TEMPLATE_DIR/docker/traefik"
mkdir -p "$TRAEFIK_DIR"

cat <<'EOF' > $TRAEFIK_DIR/traefik.yml
entryPoints:
  web:
    address: ":80"

providers:
  docker:
    exposedByDefault: false

api:
  dashboard: true
EOF

cat <<'EOF' > $TRAEFIK_DIR/docker-compose.yml
version: "3.9"
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
    networks:
      - traefik_net
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"

networks:
  traefik_net:
    name: traefik_net
    driver: bridge
EOF

echo ""
echo "✅ Full project-wise template with Nginx + Traefik created at $TEMPLATE_DIR"
echo ""
echo "Next steps:"
echo "1️⃣ Create shared network:"
echo "   docker network create traefik_net"
echo ""
echo "2️⃣ Add hosts entries:"
echo "   sudo nano /etc/hosts"
echo "   127.0.0.1 laravel.local fastapi.local react.local"
echo ""
echo "3️⃣ Start Traefik first:"
echo "   cd docker/traefik && docker compose up -d"
echo ""
echo "4️⃣ Start projects:"
echo "   cd projects/laravel && docker compose up -d --build"
echo "   cd projects/fastapi && docker compose up -d --build"
echo "   cd projects/react && docker compose up -d --build"
echo ""
echo "5️⃣ Access apps:"
echo "   http://laravel.local    (Traefik → Nginx → PHP-FPM)"
echo "   http://fastapi.local    (Traefik → Uvicorn)"
echo "   http://react.local      (Traefik → Vite)"
echo "   http://localhost:8080   (Traefik Dashboard)"
