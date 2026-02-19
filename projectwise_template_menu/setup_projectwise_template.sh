#!/bin/bash
set -e

# PROJECT-WISE DOCKER DEV WORKSPACE TEMPLATE (Interactive menu version)
BASE_DIR="/media/bot/INT-LOCAL"
TEMPLATE_NAME="docker-dev-workspace"
TEMPLATE_DIR="$BASE_DIR/$TEMPLATE_NAME"

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
esac

mkdir -p docker/traefik
touch README.md

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

# README
cat <<'READMEEOF' > README.md
# Docker Dev Workspace (Interactive Menu Version)

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
./setup_projectwise_template.sh
# (Follow the prompts for project type and project name)
```

## Start
```bash
# 1. Create the Traefik network (once):
docker network create traefik_net

# 2. Start Traefik (reverse proxy):
cd projects/traefik && docker compose up -d

# 3. Create a project (see above)

# 4. Start a project:
cd projects/<project-type>/<project-name>
docker compose up -d --build
```

## Local domains (add to /etc/hosts)
Add your project domains for local routing. Example:
```
127.0.0.1 blog.local analytics.local dashboard.local api-gateway.local
```

## Traefik Dashboard
Access at: [http://localhost:8080/dashboard/](http://localhost:8080/dashboard/)

## Notes
- Each project is isolated under `projects/<type>/<project-name>`
- Traefik is shared for all projects (runs once)
- All databases run on your local machine, not in Docker
- Edit `.env` in each project for DB credentials

See this README for troubleshooting and advanced usage.
READMEEOF
