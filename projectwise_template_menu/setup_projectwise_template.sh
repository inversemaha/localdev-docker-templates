#!/bin/bash
set -e

# ==============================================================================
#  PROJECT-WISE DOCKER DEV WORKSPACE TEMPLATE (Interactive menu version)
# ==============================================================================
#  Usage: ./setup_projectwise_template.sh
#  Then select project type from menu and enter project name.
#
#  Philosophy:
#    - Docker = App containers ONLY (language runtimes, web servers)
#    - Databases & Redis = LOCAL machine (better perf, single source of truth)
#    - Containers reach host DB via "host.docker.internal"
#    - Traefik for clean local domain routing
#    - Each project is isolated, uses only the DB it needs
# ==============================================================================

# ------------------------------
# VARIABLES
# ------------------------------
BASE_DIR="/media/bot/INT-LOCAL1"
TEMPLATE_NAME="docker-dev-workspace"
TEMPLATE_DIR="$BASE_DIR/$TEMPLATE_NAME"

echo "============================================================"
echo "  Creating project-wise Docker workspace at:"
echo "  $TEMPLATE_DIR"
echo "============================================================"
echo ""
echo "  DB/Redis/Cache: LOCAL machine (not in Docker)"
echo "  Docker: App runtimes only"
echo ""

# ------------------------------
# CREATE TEMPLATE FOLDER
# ------------------------------
mkdir -p "$TEMPLATE_DIR"
cd "$TEMPLATE_DIR"

# Interactive menu for project type
PS3="Select the project type: "

options=("fastapi" "laravel" "react" "golang" "quit")
while true; do
  select opt in "${options[@]}"; do
    case $opt in
      fastapi|laravel|react|golang)
        PROJECT_TYPE="$opt"
        break 2
        ;;
      quit)
        echo "Exiting."
        exit 0
        ;;
      *)
        echo "Invalid option. Please select a valid project type."
        ;;
    esac
  done
done

read -rp "Enter your project name: " PROJECT_NAME
if [[ -z "$PROJECT_NAME" ]]; then
  echo "Project name cannot be empty. Exiting."
  exit 1
fi

PROJECT_DIR="$TEMPLATE_DIR/projects/$PROJECT_TYPE/$PROJECT_NAME"

case "$PROJECT_TYPE" in
  fastapi)
    mkdir -p "$PROJECT_DIR"
    ;;
  laravel)
    mkdir -p "$PROJECT_DIR/nginx"
    ;;
  react)
    mkdir -p "$PROJECT_DIR"
    ;;
  golang)
    mkdir -p "$PROJECT_DIR"
    ;;
esac

mkdir -p docker/traefik

# ==============================================================================
# LARAVEL TEMPLATE (Nginx + PHP-FPM → Local MySQL + Redis)
# ==============================================================================
if [[ "$PROJECT_TYPE" == "laravel" ]]; then
  LARAVEL_DIR="$PROJECT_DIR"
  mkdir -p "$LARAVEL_DIR/nginx"
  cat <<'EOF' > $LARAVEL_DIR/.env.example
# ---- App Ports ----
APP_PORT=8080

# ---- Local MySQL (running on host machine) ----
DB_CONNECTION=mysql
DB_HOST=host.docker.internal
DB_PORT=3306
DB_DATABASE={{PROJECT_NAME}}
DB_USERNAME=root
DB_PASSWORD=root

# ---- Local Redis (running on host machine) ----
REDIS_HOST=host.docker.internal
REDIS_PORT=6379
REDIS_PASSWORD=null

# ---- Queue ----
QUEUE_CONNECTION=redis
EOF

  cat <<'EOF' > $LARAVEL_DIR/Dockerfile
FROM php:8.3-fpm

RUN apt-get update && apt-get install -y \
    git unzip libzip-dev libpng-dev zip libonig-dev libxml2-dev \
    libfreetype6-dev libjpeg62-turbo-dev libwebp-dev supervisor \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install pdo pdo_mysql zip gd bcmath pcntl \
    && pecl install redis xdebug \
    && docker-php-ext-enable redis xdebug \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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

    client_max_body_size 50M;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass {{PROJECT_NAME}}_app:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  cat <<'EOF' > $LARAVEL_DIR/docker-compose.yml
services:
  nginx:
    image: nginx:alpine
    container_name: {{PROJECT_NAME}}_nginx
    volumes:
      - ./:/var/www/html
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
    ports:
      - "${APP_PORT:-8080}:80"
    depends_on:
      - app
    networks:
      - app_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{{PROJECT_NAME}}.rule=Host(`{{PROJECT_NAME}}.local`)"
      - "traefik.http.services.{{PROJECT_NAME}}.loadbalancer.server.port=80"

  app:
    build: .
    container_name: {{PROJECT_NAME}}_app
    volumes:
      - ./:/var/www/html
    env_file:
      - .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - app_net

networks:
  app_net:
  traefik_net:
    external: true
EOF
fi

# ==============================================================================
# FASTAPI TEMPLATE (Python → Local PostgreSQL / MongoDB)
# ==============================================================================
if [[ "$PROJECT_TYPE" == "fastapi" ]]; then
  FASTAPI_DIR="$PROJECT_DIR"

  cat <<'EOF' > $FASTAPI_DIR/.env.example
# ---- App Ports ----
APP_PORT=8000

# ---- Local PostgreSQL (running on host machine) ----
DATABASE_URL=postgresql://postgres:root@host.docker.internal:5432/{{PROJECT_NAME}}

# ---- Local MongoDB (running on host machine) ----
MONGO_URL=mongodb://host.docker.internal:27017/{{PROJECT_NAME}}

# ---- Local Redis (running on host machine) ----
REDIS_URL=redis://host.docker.internal:6379/0
EOF

  cat <<'EOF' > $FASTAPI_DIR/Dockerfile
FROM python:3.13-slim

WORKDIR /app

# System deps for psycopg2, ML libs
RUN apt-get update && apt-get install -y \
    gcc libpq-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY requirements.txt* ./
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Default useful packages
RUN pip install --no-cache-dir \
    fastapi uvicorn[standard] \
    sqlalchemy psycopg2-binary pymongo motor \
    redis pydantic-settings python-dotenv \
    httpx python-multipart

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
EOF

  cat <<'EOF' > $FASTAPI_DIR/docker-compose.yml
services:
  app:
    build: .
    container_name: {{PROJECT_NAME}}_app
    volumes:
      - ./:/app
    ports:
      - "${APP_PORT:-8000}:8000"
    env_file:
      - .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - app_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{{PROJECT_NAME}}.rule=Host(`{{PROJECT_NAME}}.local`)"
      - "traefik.http.services.{{PROJECT_NAME}}.loadbalancer.server.port=8000"

networks:
  app_net:
  traefik_net:
    external: true
EOF

  cat <<'EOF' > $FASTAPI_DIR/main.py
from fastapi import FastAPI
import os

app = FastAPI(title=os.getenv("PROJECT_NAME", "FastAPI App"))

@app.get("/")
def root():
    return {"status": "running", "message": "App is connected to local databases"}

@app.get("/health")
def health():
    return {"status": "healthy"}
EOF
fi

# ==============================================================================
# REACT TEMPLATE (Node/Vite — no DB needed, pure frontend)
# ==============================================================================
if [[ "$PROJECT_TYPE" == "react" ]]; then
  REACT_DIR="$PROJECT_DIR"

  cat <<'EOF' > $REACT_DIR/.env.example
# ---- App Ports ----
APP_PORT=5173

# ---- API Base URL (point to your backend project) ----
VITE_API_URL=http://localhost:8000
EOF

  cat <<'EOF' > $REACT_DIR/Dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package*.json ./
RUN if [ -f package.json ]; then npm install; fi
EXPOSE 5173
CMD ["npm", "run", "dev", "--", "--host"]
EOF

  cat <<'EOF' > $REACT_DIR/docker-compose.yml
services:
  app:
    build: .
    container_name: {{PROJECT_NAME}}_app
    volumes:
      - ./:/app
      - /app/node_modules
    ports:
      - "${APP_PORT:-5173}:5173"
    env_file:
      - .env
    networks:
      - app_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{{PROJECT_NAME}}.rule=Host(`{{PROJECT_NAME}}.local`)"
      - "traefik.http.services.{{PROJECT_NAME}}.loadbalancer.server.port=5173"

networks:
  app_net:
  traefik_net:
    external: true
EOF
fi

# ==============================================================================
# GOLANG TEMPLATE (Go → Local PostgreSQL / Redis)
# ==============================================================================
if [[ "$PROJECT_TYPE" == "golang" ]]; then
  GOLANG_DIR="$PROJECT_DIR"

  cat <<'EOF' > $GOLANG_DIR/.env.example
# ---- App Ports ----
APP_PORT=8090

# ---- Local PostgreSQL (running on host machine) ----
DATABASE_URL=postgresql://postgres:root@host.docker.internal:5432/{{PROJECT_NAME}}

# ---- Local Redis (running on host machine) ----
REDIS_URL=redis://host.docker.internal:6379/0
EOF

  cat <<'EOF' > $GOLANG_DIR/Dockerfile
FROM golang:1.22-alpine

RUN apk add --no-cache git gcc musl-dev

WORKDIR /app
COPY go.* ./
RUN if [ -f go.sum ]; then go mod download; fi

COPY . .
RUN if [ -f main.go ]; then go build -o server .; fi

EXPOSE 8090
CMD ["go", "run", "."]
EOF

  cat <<'EOF' > $GOLANG_DIR/docker-compose.yml
services:
  app:
    build: .
    container_name: {{PROJECT_NAME}}_app
    volumes:
      - ./:/app
    ports:
      - "${APP_PORT:-8090}:8090"
    env_file:
      - .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - app_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{{PROJECT_NAME}}.rule=Host(`{{PROJECT_NAME}}.local`)"
      - "traefik.http.services.{{PROJECT_NAME}}.loadbalancer.server.port=8090"

networks:
  app_net:
  traefik_net:
    external: true
EOF
fi

# ==============================================================================
# TRAEFIK — Local domain reverse proxy
# ==============================================================================
TRAEFIK_DIR="$TEMPLATE_DIR/docker/traefik"

# Only create Traefik config if it doesn't exist (to support multiple projects)
if [[ ! -f "$TRAEFIK_DIR/traefik.yml" ]]; then
  echo "Creating Traefik configuration for the first time..."
  cat <<'EOF' > $TRAEFIK_DIR/traefik.yml
entryPoints:
  web:
    address: ":80"

providers:
  docker:
    exposedByDefault: false

api:
  dashboard: true
  insecure: true
EOF

  cat <<'EOF' > $TRAEFIK_DIR/docker-compose.yml
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
    networks:
      - traefik_net

networks:
  traefik_net:
    name: traefik_net
    driver: bridge
EOF

  echo "Traefik configuration created successfully!"
  echo ""
  echo "🚀 IMPORTANT: Start Traefik once (run this in the traefik directory):"
  echo "   cd $TRAEFIK_DIR && docker-compose up -d"
  echo ""
else
  echo "Traefik configuration already exists - reusing for multiple projects ✅"
  echo ""
fi

# ==============================================================================
# REPLACE {{PROJECT_NAME}} PLACEHOLDERS WITH ACTUAL PROJECT NAME
# ==============================================================================
echo "Replacing {{PROJECT_NAME}} placeholders with '$PROJECT_NAME'..."
find "$PROJECT_DIR" -type f \( -name '*.yml' -o -name '*.conf' -o -name '.env*' \) \
  -exec sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" {} +

# Create .env from .env.example if it exists
if [[ -f "$PROJECT_DIR/.env.example" ]]; then
  cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
fi

# ==============================================================================
# COPY ENHANCED MAKEFILE
# ==============================================================================
echo "Copying enhanced Makefile to workspace..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAKEFILE_SOURCE="$SCRIPT_DIR/../Makefile.sh"

if [[ -f "$MAKEFILE_SOURCE" ]]; then
  cp "$MAKEFILE_SOURCE" "$TEMPLATE_DIR/Makefile"
  chmod +x "$TEMPLATE_DIR/Makefile"
  echo "✅ Enhanced Makefile copied successfully!"
else
  echo "⚠️  Warning: Makefile.sh not found in parent directory"
fi

# ==============================================================================
# DONE
# ==============================================================================
echo ""
echo "============================================================"
echo "  Project '$PROJECT_NAME' ($PROJECT_TYPE) created at:"
echo "  $PROJECT_DIR"
echo "============================================================"
echo ""
echo "🚀 Next steps:"
echo ""
echo "1️⃣ Start Traefik (if not already running):"
echo "   cd $TRAEFIK_DIR && docker-compose up -d"
echo ""
echo "2️⃣ Start this project:"
echo "   cd $PROJECT_DIR"
echo "   # Edit .env with your local DB credentials"
echo "   docker compose up -d --build"
echo ""
echo "3️⃣ Access your project:"
echo "   🌐 http://$PROJECT_NAME.local"
echo "   📊 Traefik Dashboard: http://localhost:8080"
echo ""
echo "💡 MULTIPLE PROJECTS:"
echo "   ✅ Run this script again to create more projects"
echo "   ✅ All projects can run simultaneously with unique domains"
echo "   ✅ Each project gets: projectname.local"
echo "   ⚡ Start/stop projects independently with docker compose"
echo ""
echo "🛠️  ENHANCED MAKEFILE COMMANDS (from workspace directory):"
echo "   make up P=$PROJECT_NAME              # Auto-find & start project"
echo "   make up P=$PROJECT_NAME TYPE=$PROJECT_TYPE   # Explicit type (faster)"
echo "   make logs P=$PROJECT_NAME           # Follow logs"
echo "   make shell P=$PROJECT_NAME          # Shell into container"
echo "   make list                     # Show all projects by type"
echo "   make traefik-up              # Start Traefik reverse proxy"
echo ""
echo "📖 Full documentation: $TEMPLATE_DIR/README.md"
echo ""
