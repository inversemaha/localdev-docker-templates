#!/bin/bash
set -e

# ==============================================================================
#  PROJECT-WISE DOCKER DEV WORKSPACE TEMPLATE
# ==============================================================================
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
BASE_DIR="/media/bot/INT-LOCAL"
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

# Subfolders for each language/framework template
mkdir -p templates/laravel/nginx
mkdir -p templates/fastapi
mkdir -p templates/react
mkdir -p templates/golang
mkdir -p docker/traefik

touch README.md

# ==============================================================================
# README
# ==============================================================================
cat <<'READMEEOF' > README.md
# Docker Dev Workspace

## Architecture
```
Docker containers  =  App runtimes ONLY (PHP, Python, Node, Go)
Local machine      =  All databases (MySQL, PostgreSQL, MongoDB, Redis, etc.)
Traefik            =  Local domain routing (*.local)
```

## Why local databases?
- Better performance (no Docker volume overhead)
- Easier debugging & administration (use native CLI tools)
- Single source of truth — all projects share the same DB server
- No data loss from accidental `docker compose down -v`
- Professional setup — mirrors how production infra is separated

## How containers connect to local DB
All docker-compose files use:
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```
This maps `host.docker.internal` to your machine's IP inside the container.

Your app config uses `host.docker.internal` as the DB host:
```
DB_HOST=host.docker.internal
REDIS_HOST=host.docker.internal
```

## Prerequisite: Allow DB to accept connections from Docker
Your local DB must listen on `0.0.0.0` (not just `127.0.0.1`).

**MySQL** — `/etc/mysql/mysql.conf.d/mysqld.cnf`:
```
bind-address = 0.0.0.0
```
Then: `GRANT ALL ON *.* TO 'dev'@'172.%' IDENTIFIED BY 'password';`

**PostgreSQL** — `postgresql.conf`:
```
listen_addresses = '*'
```
And in `pg_hba.conf`:
```
host all all 172.0.0.0/8 md5
```

**MongoDB** — `mongod.conf`:
```
net:
  bindIp: 0.0.0.0
```

**Redis** — `/etc/redis/redis.conf`:
```
bind 0.0.0.0
protected-mode no  # or set a password
```

After changes, restart each service: `sudo systemctl restart mysql postgresql mongod redis`

## Creating a new project
```bash
./create_project.sh laravel my-app
./create_project.sh fastapi ml-service
./create_project.sh react dashboard
./create_project.sh golang api-gateway
```

## Start
```bash
cd docker/traefik && docker compose up -d         # Start Traefik first
cd projects/my-app && docker compose up -d --build  # Start any project
```

## Local domains (add to /etc/hosts)
```
127.0.0.1 laravel.local fastapi.local react.local golang.local
```
READMEEOF

# ==============================================================================
# CREATE PROJECT SCRIPT — clones a template into projects/<name>
# ==============================================================================
cat <<'CPEOF' > "$TEMPLATE_DIR/create_project.sh"
#!/bin/bash
set -e

WORKSPACE_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$WORKSPACE_DIR/templates"
PROJECTS_DIR="$WORKSPACE_DIR/projects"

TEMPLATE="$1"
PROJECT_NAME="$2"

if [[ -z "$TEMPLATE" || -z "$PROJECT_NAME" ]]; then
  echo "Usage: ./create_project.sh <template> <project-name>"
  echo ""
  echo "Available templates:"
  ls -1 "$TEMPLATES_DIR"
  exit 1
fi

if [[ ! -d "$TEMPLATES_DIR/$TEMPLATE" ]]; then
  echo "ERROR: Template '$TEMPLATE' not found."
  echo "Available: $(ls -1 "$TEMPLATES_DIR" | tr '\n' ' ')"
  exit 1
fi

TARGET="$PROJECTS_DIR/$PROJECT_NAME"
if [[ -d "$TARGET" ]]; then
  echo "ERROR: Project '$PROJECT_NAME' already exists at $TARGET"
  exit 1
fi

echo "Creating project '$PROJECT_NAME' from template '$TEMPLATE'..."
mkdir -p "$PROJECTS_DIR"
cp -r "$TEMPLATES_DIR/$TEMPLATE" "$TARGET"

# Replace placeholder container names with project-specific names
find "$TARGET" -type f -name '*.yml' -exec sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" {} +
find "$TARGET" -type f -name '*.conf' -exec sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" {} +
find "$TARGET" -type f -name '.env*' -exec sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" {} +

# Create .env from .env.example if it exists
if [[ -f "$TARGET/.env.example" ]]; then
  cp "$TARGET/.env.example" "$TARGET/.env"
fi

echo ""
echo "Project created at: $TARGET"
echo ""
echo "Next steps:"
echo "  cd $TARGET"
echo "  # Edit .env with your local DB credentials"
echo "  docker compose up -d --build"
echo ""
CPEOF
chmod +x "$TEMPLATE_DIR/create_project.sh"

# ==============================================================================
# LARAVEL TEMPLATE (Nginx + PHP-FPM → Local MySQL + Redis)
# ==============================================================================
LARAVEL_DIR="$TEMPLATE_DIR/templates/laravel"

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

# ==============================================================================
# FASTAPI TEMPLATE (Python → Local PostgreSQL / MongoDB)
# ==============================================================================
FASTAPI_DIR="$TEMPLATE_DIR/templates/fastapi"

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
FROM python:3.14-slim

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

# ==============================================================================
# REACT TEMPLATE (Node/Vite — no DB needed, pure frontend)
# ==============================================================================
REACT_DIR="$TEMPLATE_DIR/templates/react"

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

# ==============================================================================
# GOLANG TEMPLATE (Go → Local PostgreSQL / Redis)
# ==============================================================================
GOLANG_DIR="$TEMPLATE_DIR/templates/golang"

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

# ==============================================================================
# TRAEFIK — Local domain reverse proxy
# ==============================================================================
TRAEFIK_DIR="$TEMPLATE_DIR/docker/traefik"

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

# ==============================================================================
# DONE
# ==============================================================================
echo ""
echo "============================================================"
echo "  DONE! Workspace created at: $TEMPLATE_DIR"
echo "============================================================"
echo ""
echo "  Structure:"
echo "  $TEMPLATE_NAME/"
echo "    templates/"
echo "      laravel/       PHP 8.3 + Nginx + Supervisor"
echo "      fastapi/       Python 3.14 + Uvicorn"
echo "      react/         Node 24 + Vite"
echo "      golang/        Go 1.22"
echo "    docker/"
echo "      traefik/       Local domain routing"
echo "    projects/         Your actual projects go here"
echo "    create_project.sh Helper to scaffold new projects"
echo ""
echo "  ALL databases (MySQL, PostgreSQL, MongoDB, Redis)"
echo "  run on your LOCAL machine — NOT in Docker."
echo "  Containers connect via 'host.docker.internal'"
echo ""
echo "============================================================"
echo "  QUICK START"
echo "============================================================"
echo ""
echo "  1. Create the Traefik network:"
echo "     docker network create traefik_net"
echo ""
echo "  2. Start Traefik:"
echo "     cd $TEMPLATE_DIR/docker/traefik && docker compose up -d"
echo ""
echo "  3. Create a project:"
echo "     cd $TEMPLATE_DIR"
echo "     ./create_project.sh laravel my-blog"
echo "     ./create_project.sh fastapi ml-api"
echo "     ./create_project.sh react dashboard"
echo "     ./create_project.sh golang api-gateway"
echo ""
echo "  4. Edit .env, then start:"
echo "     cd projects/my-blog && docker compose up -d --build"
echo ""
echo "  5. Add to /etc/hosts:"
echo "     sudo sh -c 'echo \"127.0.0.1 my-blog.local ml-api.local dashboard.local\" >> /etc/hosts'"
echo ""
echo "  6. Ensure local DBs accept Docker connections:"
echo "     See README.md for bind-address config"
echo ""
echo "============================================================"
