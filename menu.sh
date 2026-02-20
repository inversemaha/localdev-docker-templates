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
# HELPER FUNCTIONS
# ------------------------------

# Function to find next available port for project type
get_next_available_port() {
  local project_type="$1"
  local base_port
  
  # Set base ports for each project type
  case "$project_type" in
    fastapi)
      base_port=8000
      ;;
    laravel)
      base_port=9000
      ;;
    react)
      base_port=3000
      ;;
    golang)
      base_port=8080
      ;;
    *)
      base_port=8000
      ;;
  esac
  
  local port=$base_port
  local projects_registry="$TEMPLATE_DIR/docker/traefik/.projects_registry"
  
  # Check if port is already in external use by checking registry and running containers
  while true; do
    # Check in registry (look at external port - 3rd field)
    if [[ -f "$projects_registry" ]] && grep -q ":$port$" "$projects_registry" 2>/dev/null; then
      ((port++))
      continue
    fi
    
    # Check if port is in use by system
    if command -v netstat >/dev/null 2>&1; then
      if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        ((port++))
        continue
      fi
    fi
    
    # Check if Docker is using the port
    if docker ps --format "table {{.Ports}}" 2>/dev/null | grep -q "$port->"; then
      ((port++))
      continue
    fi
    
    break
  done
  
  echo $port
}

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

# Assign and export available port for template substitution
AVAILABLE_PORT=$(get_next_available_port "$PROJECT_TYPE")
export AVAILABLE_PORT

mkdir -p docker/traefik

# Copy Makefile.sh to workspace for easy project management
cp "$(dirname "$0")/Makefile.sh" "$TEMPLATE_DIR/" 2>/dev/null || echo "Note: Makefile.sh not found in script directory"

# ==============================================================================
# ADDITIONAL HELPER FUNCTIONS
# ==============================================================================

# Function to add DNS entry to /etc/hosts
add_dns_entry() {
  local domain="$1"
  
  # Check if domain already exists in /etc/hosts
  if grep -q "$domain" /etc/hosts 2>/dev/null; then
    echo "DNS entry for $domain already exists in /etc/hosts"
    return 0
  fi
  
  # Try to add DNS entry with sudo
  if command -v sudo >/dev/null 2>&1; then
    echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      echo "Added $domain to /etc/hosts"
    else
      echo "Warning: Could not add $domain to /etc/hosts. You may need to add it manually:"
      echo "  echo '127.0.0.1 $domain' | sudo tee -a /etc/hosts"
    fi
  else
    echo "Warning: sudo not available. Please add DNS entry manually:"
    echo "  echo '127.0.0.1 $domain' >> /etc/hosts"
  fi
}

# Function to populate registry with existing projects
populate_existing_projects() {
  local projects_registry="$TEMPLATE_DIR/docker/traefik/.projects_registry"
  local projects_dir="$TEMPLATE_DIR/projects"
  
  if [[ ! -d "$projects_dir" ]]; then
    return 0
  fi
  
  echo "Scanning for existing projects to add to registry..."
  
  for project_type_dir in "$projects_dir"/*; do
    [[ ! -d "$project_type_dir" ]] && continue
    
    local project_type=$(basename "$project_type_dir")
    
    for project_dir in "$project_type_dir"/*; do
      [[ ! -d "$project_dir" ]] && continue
      [[ ! -f "$project_dir/docker-compose.yml" ]] && continue
      
      local project_name=$(basename "$project_dir")
      
      # Skip if already in registry
      if [[ -f "$projects_registry" ]] && grep -q "^$project_name:" "$projects_registry" 2>/dev/null; then
        continue
      fi
      
      # Determine port from .env file
      local app_port
      if [[ -f "$project_dir/.env" ]]; then
        app_port=$(grep "^APP_PORT=" "$project_dir/.env" 2>/dev/null | cut -d= -f2 | tr -d ' ')
      fi
      
      # Set default port if not found
      if [[ -z "$app_port" ]]; then
        case "$project_type" in
          fastapi) app_port=8000 ;;
          laravel) app_port=9000 ;;
          react) app_port=3000 ;;
          golang) app_port=8080 ;;
          *) app_port=8000 ;;
        esac
      fi
      
      # Add to registry
      if [[ ! -f "$projects_registry" ]]; then
        mkdir -p "$(dirname "$projects_registry")"
        echo "# Format: PROJECT_NAME:PROJECT_TYPE:EXTERNAL_PORT" > "$projects_registry"
      fi
      
      echo "$project_name:$project_type:$app_port" >> "$projects_registry"
      echo "  Added existing project: $project_name ($project_type)"
      
      # Add DNS entry
      add_dns_entry "${project_name}.local"
    done
  done
}

# Function to restart Traefik if it's running
restart_traefik_if_running() {
  local traefik_dir="$TEMPLATE_DIR/docker/traefik"
  
  if docker ps | grep -q "traefik" 2>/dev/null; then
    echo "Restarting Traefik to reload configuration..."
    if [[ -f "$traefik_dir/docker-compose.yml" ]]; then
      (cd "$traefik_dir" && docker compose restart) >/dev/null 2>&1
      sleep 2
      echo "Traefik restarted successfully"
    fi
  fi
}

# ==============================================================================
# LARAVEL TEMPLATE (Nginx + PHP-FPM → Local MySQL + Redis)
# ==============================================================================
if [[ "$PROJECT_TYPE" == "laravel" ]]; then
  LARAVEL_DIR="$PROJECT_DIR"
  mkdir -p "$LARAVEL_DIR/nginx"
  cat <<'EOF' > $LARAVEL_DIR/.env.example
# ---- App Ports ----
APP_PORT=${AVAILABLE_PORT}

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

  # Create basic composer.json
  cat <<'EOF' > $LARAVEL_DIR/composer.json
{
    "name": "{{PROJECT_NAME}}/laravel-app",
    "type": "project",
    "description": "Laravel application generated by MEMAHA template",
    "keywords": ["laravel", "framework"],
    "license": "MIT",
    "require": {
        "php": "^8.2",
        "laravel/framework": "^11.0",
        "laravel/tinker": "^2.9"
    },
    "require-dev": {
        "fakerphp/faker": "^1.23",
        "laravel/pint": "^1.13",
        "laravel/sail": "^1.26",
        "mockery/mockery": "^1.6",
        "nunomaduro/collision": "^8.0",
        "phpunit/phpunit": "^11.0.1"
    },
    "autoload": {
        "psr-4": {
            "App\\": "app/",
            "Database\\Factories\\": "database/factories/",
            "Database\\Seeders\\": "database/seeders/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "Tests\\": "tests/"
        }
    },
    "scripts": {
        "post-autoload-dump": [
            "Illuminate\\Foundation\\ComposerScripts::postAutoloadDump",
            "@php artisan package:discover --ansi"
        ],
        "post-update-cmd": [
            "@php artisan vendor:publish --tag=laravel-assets --ansi --force"
        ],
        "post-root-package-install": [
            "@php -r \"file_exists('.env') || copy('.env.example', '.env');\""
        ],
        "post-create-project-cmd": [
            "@php artisan key:generate --ansi",
            "@php -r \"file_exists('database/database.sqlite') || touch('database/database.sqlite');\"",
            "@php artisan migrate --graceful --ansi"
        ]
    },
    "extra": {
        "laravel": {
            "dont-discover": []
        }
    },
    "config": {
        "optimize-autoloader": true,
        "preferred-install": "dist",
        "sort-packages": true,
        "allow-plugins": {
            "pestphp/pest-plugin": true,
            "php-http/discovery": true
        }
    },
    "minimum-stability": "stable",
    "prefer-stable": true
}
EOF
fi

# ==============================================================================
# FASTAPI TEMPLATE (Python → Local PostgreSQL / MongoDB)
# ==============================================================================
if [[ "$PROJECT_TYPE" == "fastapi" ]]; then
  FASTAPI_DIR="$PROJECT_DIR"

  cat <<'EOF' > $FASTAPI_DIR/.env.example
# ---- App Ports ----
APP_PORT=${AVAILABLE_PORT}

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

  cat <<'EOF' > $FASTAPI_DIR/requirements.txt
fastapi==0.115.0
uvicorn[standard]==0.30.0
sqlalchemy==2.0.35
psycopg2-binary==2.9.10
pymongo==4.9.0
motor==3.6.0
redis==5.2.0
pydantic-settings==2.5.0
python-dotenv==1.0.1
httpx==0.27.2
python-multipart==0.0.12
pytest==8.3.3
EOF
fi

# ==============================================================================
# REACT TEMPLATE (Node/Vite — no DB needed, pure frontend)
# ==============================================================================
if [[ "$PROJECT_TYPE" == "react" ]]; then
  REACT_DIR="$PROJECT_DIR"

  cat <<'EOF' > $REACT_DIR/.env.example
# ---- App Ports ----
APP_PORT=${AVAILABLE_PORT}

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

  # Create package.json
  cat <<'EOF' > $REACT_DIR/package.json
{
  "name": "{{PROJECT_NAME}}",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "@vitejs/plugin-react": "^4.3.3",
    "typescript": "~5.6.2",
    "vite": "^5.4.10"
  }
}
EOF

  # Create basic React app structure
  mkdir -p "$REACT_DIR/src"
  
  cat <<'EOF' > $REACT_DIR/index.html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>{{PROJECT_NAME}}</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

  cat <<'EOF' > $REACT_DIR/src/main.tsx
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

  cat <<'EOF' > $REACT_DIR/src/App.tsx
import { useState } from 'react'

function App() {
  const [count, setCount] = useState(0)

  return (
    <>
      <h1>{{PROJECT_NAME}}</h1>
      <div className="card">
        <button onClick={() => setCount((count) => count + 1)}>
          count is {count}
        </button>
        <p>Edit src/App.tsx and save to test HMR</p>
      </div>
    </>
  )
}

export default App
EOF

  cat <<'EOF' > $REACT_DIR/src/index.css
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

.card {
  padding: 2rem;
}
EOF

  cat <<'EOF' > $REACT_DIR/vite.config.ts
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
fi

# ==============================================================================
# GOLANG TEMPLATE (Go → Local PostgreSQL / Redis)
# ==============================================================================
if [[ "$PROJECT_TYPE" == "golang" ]]; then
  GOLANG_DIR="$PROJECT_DIR"

  cat <<'EOF' > $GOLANG_DIR/.env.example
# ---- App Ports ----
APP_PORT=${AVAILABLE_PORT}

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

  # Create go.mod
  cat <<'EOF' > $GOLANG_DIR/go.mod
module {{PROJECT_NAME}}

go 1.22

require (
	github.com/gin-gonic/gin v1.10.0
	github.com/lib/pq v1.10.9
	github.com/redis/go-redis/v9 v9.7.0
	github.com/joho/godotenv v1.5.1
)
EOF

  # Create basic main.go
  cat <<'EOF' > $GOLANG_DIR/main.go
package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env file
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found")
	}

	r := gin.Default()

	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"project": "{{PROJECT_NAME}}",
			"status":  "running",
			"message": "Go application ready",
		})
	})

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "{{PROJECT_NAME}}",
		})
	})

	port := os.Getenv("APP_PORT")
	if port == "" {
		port = "8090"
	}

	log.Printf("Starting server on port %s", port)
	r.Run(":" + port)
}
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
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

api:
  dashboard: true
  insecure: true
EOF

  cat <<'EOF' > $TRAEFIK_DIR/dynamic.yml
http:
  routers: {}
  services: {}
EOF

  cat <<'EOF' > $TRAEFIK_DIR/docker-compose.yml
services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "8080:8080"
    volumes:
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic.yml:/etc/traefik/dynamic.yml:rw
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
# REPLACE {{PROJECT_NAME}} AND ${AVAILABLE_PORT} PLACEHOLDERS
# ==============================================================================
echo "Replacing placeholders with actual values..."
find "$PROJECT_DIR" -type f \( -name '*.yml' -o -name '*.conf' -o -name '.env*' \) \
  -exec sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" {} +

find "$PROJECT_DIR" -type f \( -name '*.yml' -o -name '*.conf' -o -name '.env*' \) \
  -exec sed -i "s/\${AVAILABLE_PORT}/$AVAILABLE_PORT/g" {} +

# Create .env from .env.example if it exists
if [[ -f "$PROJECT_DIR/.env.example" ]]; then
  cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
  # Replace placeholders in the new .env file too
  sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$PROJECT_DIR/.env"
  sed -i "s/\${AVAILABLE_PORT}/$AVAILABLE_PORT/g" "$PROJECT_DIR/.env"
fi

# Clean up any remaining literal ${AVAILABLE_PORT} that didn't get replaced
find "$PROJECT_DIR" -type f \( -name '*.yml' -o -name '*.conf' -o -name '.env*' \) \
  -exec sed -i "s/APP_PORT=\${AVAILABLE_PORT}/APP_PORT=$AVAILABLE_PORT/g" {} +

# ==============================================================================
# ADD STATIC ROUTING TO TRAEFIK
# ==============================================================================
echo "Adding static routing for $PROJECT_NAME to Traefik..."

# Determine the port for the service based on project type
case "$PROJECT_TYPE" in
  fastapi)
    SERVICE_PORT=8000
    ;;
  laravel)
    SERVICE_PORT=80
    ;;
  react)
    SERVICE_PORT=5173
    ;;
  golang)
    SERVICE_PORT=8090
    ;;
  *)
    SERVICE_PORT=80
    ;;
esac

# Update Traefik dynamic configuration for multi-project support
update_traefik_config() {
  local project_name="$1"
  local service_port="$2"
  local project_type="$3"
  local dynamic_file="$TEMPLATE_DIR/docker/traefik/dynamic.yml"
  local projects_registry="$TEMPLATE_DIR/docker/traefik/.projects_registry"
  
  # Create projects registry if it doesn't exist
  if [[ ! -f "$projects_registry" ]]; then
    mkdir -p "$(dirname "$projects_registry")"
    echo "# Format: PROJECT_NAME:PROJECT_TYPE:EXTERNAL_PORT" > "$projects_registry"
  fi
  
  # Remove existing entry for this project and add new one
  if [[ -f "$projects_registry" ]]; then
    grep -v "^${project_name}:" "$projects_registry" > "${projects_registry}.tmp" 2>/dev/null || echo "# Format: PROJECT_NAME:PROJECT_TYPE:EXTERNAL_PORT" > "${projects_registry}.tmp"
  else
    echo "# Format: PROJECT_NAME:PROJECT_TYPE:EXTERNAL_PORT" > "${projects_registry}.tmp"
  fi
  
  # Use AVAILABLE_PORT for external, but internal container port for service communication
  local external_port="${AVAILABLE_PORT}"
  if [[ -z "$external_port" ]]; then
    external_port="$service_port"  # Fallback to service_port if AVAILABLE_PORT not set
  fi
  echo "${project_name}:${project_type}:${external_port}" >> "${projects_registry}.tmp"
  mv "${projects_registry}.tmp" "$projects_registry"
  
  # Add DNS entry automatically
  add_dns_entry "${project_name}.local"
  
  # Regenerate dynamic.yml from registry
  cat > "$dynamic_file" <<EOF
http:
  routers:
EOF
  
  # Add all router configurations
  while IFS=':' read -r proj_name proj_type proj_port; do
    [[ "$proj_name" =~ ^#.*$ ]] && continue  # Skip comments
    [[ -z "$proj_name" ]] && continue        # Skip empty lines
    cat >> "$dynamic_file" <<EOF
    ${proj_name}:
      rule: "Host(\`${proj_name}.local\`)"
      service: ${proj_name}
EOF
  done < "$projects_registry"
  
  cat >> "$dynamic_file" <<EOF
  services:
EOF
  
  # Add all service configurations
  while IFS=':' read -r proj_name proj_type proj_port; do
    [[ "$proj_name" =~ ^#.*$ ]] && continue  # Skip comments
    [[ -z "$proj_name" ]] && continue        # Skip empty lines
    
    # Use internal container port for service communication
    local internal_port
    case "$proj_type" in
      fastapi|laravel|golang)
        internal_port=8000
        ;;
      react)
        internal_port=5173
        ;;
      *)
        internal_port=8000
        ;;
    esac
    
    cat >> "$dynamic_file" <<EOF
    ${proj_name}:
      loadBalancer:
        servers:
          - url: "http://${proj_name}_app:${internal_port}"
EOF
  done < "$projects_registry"
  
  echo "Updated Traefik configuration for $project_name (and all active projects)"
  
  # Restart Traefik to reload configuration
  restart_traefik_if_running
}

# ==============================================================================
# UPDATE TRAEFIK CONFIG AND CLEANUP REGISTRY
# ==============================================================================
update_traefik_config "${PROJECT_NAME}" "${AVAILABLE_PORT}" "${PROJECT_TYPE}"

# Clean up registry - remove any entries with empty ports
projects_registry="$TEMPLATE_DIR/docker/traefik/.projects_registry"
if [[ -f "$projects_registry" ]]; then
  # Remove lines that end with : (empty port)
  sed -i '/:[[:space:]]*$/d' "$projects_registry"
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
    
