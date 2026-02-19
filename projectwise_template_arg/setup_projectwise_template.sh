#!/bin/bash
set -e

# PROJECT-WISE DOCKER DEV WORKSPACE TEMPLATE (Command-line argument version)
BASE_DIR="/media/bot/INT-LOCAL"
TEMPLATE_NAME="docker-dev-workspace"
TEMPLATE_DIR="$BASE_DIR/$TEMPLATE_NAME"

mkdir -p "$TEMPLATE_DIR"
cd "$TEMPLATE_DIR"

# Command-line argument for project type
PROJECT_TYPE="$1"

if [[ -z "$PROJECT_TYPE" ]]; then
  echo "Usage: $0 <project-type>"
  echo "Available project types: fastapi, laravel, react, golang"
  exit 1
fi

case "$PROJECT_TYPE" in
  fastapi)
    mkdir -p projects/fastapi
    ;;
  laravel)
    mkdir -p projects/laravel/nginx
    ;;
  react)
    mkdir -p projects/react
    ;;
  golang)
    mkdir -p projects/golang
    ;;
  *)
    echo "Unknown project type: $PROJECT_TYPE"
    echo "Available project types: fastapi, laravel, react, golang"
    exit 1
    ;;
esac

# Always create Traefik reverse proxy files under projects/traefik
TRAEFIK_DIR="$TEMPLATE_DIR/projects/traefik"
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

# Template generation blocks
if [[ "$PROJECT_TYPE" == "laravel" ]]; then
  LARAVEL_DIR="$TEMPLATE_DIR/projects/laravel"
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
  # ...add other Laravel template files here...
fi

if [[ "$PROJECT_TYPE" == "fastapi" ]]; then
  FASTAPI_DIR="$TEMPLATE_DIR/projects/fastapi"
  mkdir -p "$FASTAPI_DIR"
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
  # ...add other FastAPI template files here...
fi

if [[ "$PROJECT_TYPE" == "react" ]]; then
  REACT_DIR="$TEMPLATE_DIR/projects/react"
  mkdir -p "$REACT_DIR"
  cat <<'EOF' > $REACT_DIR/.env.example
# ---- App Ports ----
APP_PORT=5173
# ---- API Base URL (point to your backend project) ----
VITE_API_URL=http://localhost:8000
EOF
  # ...add other React template files here...
fi

if [[ "$PROJECT_TYPE" == "golang" ]]; then
  GOLANG_DIR="$TEMPLATE_DIR/projects/golang"
  mkdir -p "$GOLANG_DIR"
  cat <<'EOF' > $GOLANG_DIR/.env.example
# ---- App Ports ----
APP_PORT=8090
# ---- Local PostgreSQL (running on host machine) ----
DATABASE_URL=postgresql://postgres:root@host.docker.internal:5432/{{PROJECT_NAME}}
# ---- Local Redis (running on host machine) ----
REDIS_URL=redis://host.docker.internal:6379/0
EOF
  # ...add other Golang template files here...
fi

echo "Project template for $PROJECT_TYPE created in $TEMPLATE_DIR."
