#!/bin/bash
set -e

# ==============================================================================
#  PROJECT-WISE DOCKER DEV WORKSPACE TEMPLATE (Interactive menu version)
# ==============================================================================
#  Usage: ./menu.sh
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

# Copy Makefile.sh to workspace for easy project management
cp "$(dirname "$0")/Makefile.sh" "$TEMPLATE_DIR/" 2>/dev/null || echo "Note: Makefile.sh not found in script directory"

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
echo "🛠️  MAKEFILE SHORTCUTS (from workspace directory):"
echo "   ./Makefile.sh traefik-up                    # Start Traefik"
echo "   ./Makefile.sh up PROJECT=$PROJECT_NAME            # Auto-find & start project"
echo "   ./Makefile.sh logs PROJECT=$PROJECT_NAME          # View project logs"
echo "   ./Makefile.sh list                          # Show all projects by type"
echo ""
    local project_name="$1"
    local project_dir="$WORKSPACE_DIR/projects/fastapi/$project_name"
    
    log_info "Creating FastAPI project: $project_name"
    mkdir -p "$project_dir"
    
    # Environment file
    cat > "$project_dir/.env" << EOF
# FastAPI Configuration
APP_NAME=$project_name
APP_PORT=8000
DEBUG=true

# Database URLs (host-based)
DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:5432/${project_name}
MONGO_URL=mongodb://host.docker.internal:27017/${project_name}
REDIS_URL=redis://host.docker.internal:6379/0
EOF

    # Dockerfile
    cat > "$project_dir/Dockerfile" << 'EOF'
FROM python:3.13-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt* ./
RUN pip install --no-cache-dir \
    fastapi uvicorn[standard] \
    sqlalchemy psycopg2-binary \
    pymongo motor redis \
    pydantic-settings python-dotenv \
    httpx python-multipart

COPY . .
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
EOF

    # Docker Compose
    cat > "$project_dir/docker-compose.yml" << EOF
services:
  app:
    build: .
    container_name: ${project_name}_app
    volumes:
      - ./:/app
    ports:
      - "\${APP_PORT:-8000}:8000"
    env_file: .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - app_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${project_name}.rule=Host(\`${project_name}.local\`)"
      - "traefik.http.services.${project_name}.loadbalancer.server.port=8000"

networks:
  app_net:
  traefik_net:
    external: true
EOF

    # Sample application
    cat > "$project_dir/main.py" << EOF
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os

app = FastAPI(
    title=os.getenv("APP_NAME", "$project_name"),
    description="Generated by MEMAHA template",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {
        "project": "$project_name",
        "status": "running",
        "message": "FastAPI application ready"
    }

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "$project_name"}
EOF

    # Requirements file
    cat > "$project_dir/requirements.txt" << 'EOF'
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
sqlalchemy>=2.0.0
psycopg2-binary>=2.9.0
pymongo>=4.6.0
motor>=3.3.0
redis>=5.0.0
pydantic-settings>=2.0.0
python-dotenv>=1.0.0
httpx>=0.25.0
python-multipart>=0.0.6
EOF

    log_success "FastAPI project '$project_name' created successfully"
    echo "  📁 Location: $project_dir"
    echo "  🌐 URL: http://$project_name.local (after starting)"
}

create_react_project() {
    local project_name="$1"
    local project_dir="$WORKSPACE_DIR/projects/react/$project_name"
    
    log_info "Creating React project: $project_name"
    mkdir -p "$project_dir"
    
    # Environment file
    cat > "$project_dir/.env" << EOF
# React Configuration
VITE_APP_NAME=$project_name
VITE_APP_PORT=5173

# API Configuration
VITE_API_URL=http://localhost:8000
VITE_API_TIMEOUT=30000
EOF

    # Dockerfile
    cat > "$project_dir/Dockerfile" << 'EOF'
FROM node:20-alpine

WORKDIR /app

# Install dependencies if package.json exists
COPY package*.json ./
RUN if [ -f package.json ]; then npm install; else \
    npm init -y && \
    npm install vite @vitejs/plugin-react react react-dom && \
    npm install -D @types/react @types/react-dom typescript; fi

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
EOF

    # Docker Compose
    cat > "$project_dir/docker-compose.yml" << EOF
services:
  app:
    build: .
    container_name: ${project_name}_app
    volumes:
      - ./:/app
      - /app/node_modules
    ports:
      - "\${VITE_APP_PORT:-5173}:5173"
    env_file: .env
    networks:
      - app_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${project_name}.rule=Host(\`${project_name}.local\`)"
      - "traefik.http.services.${project_name}.loadbalancer.server.port=5173"

networks:
  app_net:
  traefik_net:
    external: true
EOF

    # Package.json if it doesn't exist
    cat > "$project_dir/package.json" << EOF
{
  "name": "$project_name",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@vitejs/plugin-react": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^5.0.0"
  }
}
EOF

    # Basic React app
    mkdir -p "$project_dir/src"
    cat > "$project_dir/src/main.tsx" << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

    cat > "$project_dir/src/App.tsx" << EOF
import React, { useState, useEffect } from 'react'

function App() {
  const [status, setStatus] = useState('Loading...')

  useEffect(() => {
    setStatus('Ready')
  }, [])

  return (
    <div style={{ padding: '2rem', fontFamily: 'system-ui' }}>
      <h1>$project_name</h1>
      <p>Status: {status}</p>
      <p>Generated by MEMAHA template</p>
    </div>
  )
}

export default App
EOF

    cat > "$project_dir/src/index.css" << 'EOF'
body {
  margin: 0;
  padding: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
EOF

    # Vite config
    cat > "$project_dir/vite.config.ts" << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
  },
})
EOF

    # HTML template
    cat > "$project_dir/index.html" << EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$project_name</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

    log_success "React project '$project_name' created successfully"
    echo "  📁 Location: $project_dir"
    echo "  🌐 URL: http://$project_name.local (after starting)"
}

create_golang_project() {
    local project_name="$1"
    local project_dir="$WORKSPACE_DIR/projects/golang/$project_name"
    
    log_info "Creating Go project: $project_name"
    mkdir -p "$project_dir"
    
    # Environment file
    cat > "$project_dir/.env" << EOF
# Go Configuration
APP_NAME=$project_name
APP_PORT=8080

# Database Configuration
DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:5432/${project_name}
REDIS_URL=redis://host.docker.internal:6379/0
EOF

    # Dockerfile
    cat > "$project_dir/Dockerfile" << 'EOF'
FROM golang:1.21-alpine

RUN apk add --no-cache git gcc musl-dev

WORKDIR /app

COPY go.* ./
RUN if [ -f go.sum ]; then go mod download; fi

COPY . .
EXPOSE 8080

CMD ["go", "run", "."]
EOF

    # Docker Compose
    cat > "$project_dir/docker-compose.yml" << EOF
services:
  app:
    build: .
    container_name: ${project_name}_app
    volumes:
      - ./:/app
    ports:
      - "\${APP_PORT:-8080}:8080"
    env_file: .env
    extra_hosts:
      - "host.docker.internal:host-gateway"
    networks:
      - app_net
      - traefik_net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${project_name}.rule=Host(\`${project_name}.local\`)"
      - "traefik.http.services.${project_name}.loadbalancer.server.port=8080"

networks:
  app_net:
  traefik_net:
    external: true
EOF

    # Go module
    cat > "$project_dir/go.mod" << EOF
module $project_name

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/lib/pq v1.10.9
    github.com/redis/go-redis/v9 v9.3.0
    github.com/joho/godotenv v1.5.1
)
EOF

    # Main application
    cat > "$project_dir/main.go" << EOF
package main

import (
    "log"
    "net/http"
    "os"
    
    "github.com/gin-gonic/gin"
    "github.com/joho/godotenv"
)

func main() {
    if err := godotenv.Load(); err != nil {
        log.Println("No .env file found")
    }

    r := gin.Default()
    
    r.GET("/", func(c *gin.Context) {
        c.JSON(http.StatusOK, gin.H{
            "project": "$project_name",
            "status":  "running",
            "message": "Go application ready",
        })
    })
    
    r.GET("/health", func(c *gin.Context) {
        c.JSON(http.StatusOK, gin.H{
            "status":  "healthy",
            "service": "$project_name",
        })
    })

    port := os.Getenv("APP_PORT")
    if port == "" {
        port = "8080"
    }

    log.Printf("Starting server on port %s", port)
    r.Run(":" + port)
}
EOF

    log_success "Go project '$project_name' created successfully"
    echo "  📁 Location: $project_dir"
    echo "  🌐 URL: http://$project_name.local (after starting)"
}

# ------------------------------
# TRAEFIK SETUP
# ------------------------------
setup_traefik() {
    local traefik_dir="$WORKSPACE_DIR/infrastructure/traefik"
    
    if [[ -f "$traefik_dir/docker-compose.yml" ]]; then
        log_warning "Traefik already configured"
        return 0
    fi
    
    log_info "Setting up Traefik reverse proxy"
    mkdir -p "$traefik_dir"
    
    # Traefik configuration
    cat > "$traefik_dir/traefik.yml" << 'EOF'
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false

api:
  dashboard: true
  insecure: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
      storage: /acme.json
      httpChallenge:
        entryPoint: web
EOF

    # Traefik Docker Compose
    cat > "$traefik_dir/docker-compose.yml" << 'EOF'
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./acme.json:/acme.json
    networks:
      - traefik_net

networks:
  traefik_net:
    name: traefik_net
    driver: bridge
EOF

    # Create acme.json with correct permissions
    touch "$traefik_dir/acme.json"
    chmod 600 "$traefik_dir/acme.json"
    
    log_success "Traefik configured successfully"
    echo "  📁 Location: $traefik_dir"
    echo "  🎛️  Dashboard: http://localhost:8080"
}

# ------------------------------
# MAIN MENU
# ------------------------------
show_menu() {
    echo "Available project types:"
    echo "1) FastAPI (Python web framework)"
    echo "2) React (Frontend application)"  
    echo "3) Go (Golang web service)"
    echo "4) Setup Traefik only"
    echo "5) List existing projects"
    echo "6) Exit"
    echo ""
}

list_projects() {
    log_info "Existing projects in workspace:"
    
    if [[ ! -d "$WORKSPACE_DIR/projects" ]]; then
        echo "  No projects found"
        return
    fi
    
    for type_dir in "$WORKSPACE_DIR/projects"/*; do
        if [[ -d "$type_dir" ]]; then
            type_name=$(basename "$type_dir")
            echo "  📂 $type_name projects:"
            
            for project_dir in "$type_dir"/*; do
                if [[ -d "$project_dir" ]]; then
                    project_name=$(basename "$project_dir")
                    if [[ -f "$project_dir/docker-compose.yml" ]]; then
                        echo "    🚀 $project_name (configured)"
                    else
                        echo "    📁 $project_name (incomplete)"
                    fi
                fi
            done
        fi
    done
}

main() {
    show_header
    
    # Ensure workspace directory exists
    mkdir -p "$WORKSPACE_DIR"
    
    while true; do
        show_menu
        read -rp "Select an option (1-6): " choice
        echo ""
        
        case $choice in
            1)
                read -rp "Enter FastAPI project name: " project_name
                if validate_project_name "$project_name"; then
                    create_fastapi_project "$project_name"
                    setup_traefik
                fi
                ;;
            2)
                read -rp "Enter React project name: " project_name
                if validate_project_name "$project_name"; then
                    create_react_project "$project_name"
                    setup_traefik
                fi
                ;;
            3)
                read -rp "Enter Go project name: " project_name
                if validate_project_name "$project_name"; then
                    create_golang_project "$project_name"
                    setup_traefik
                fi
                ;;
            4)
                setup_traefik
                ;;
            5)
                list_projects
                ;;
            6)
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please select 1-6."
                ;;
        esac
        
        echo ""
        read -rp "Press Enter to continue..."
        show_header
    done
}

# ------------------------------
# SCRIPT ENTRY POINT
# ------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi