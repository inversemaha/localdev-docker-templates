# linuxmint-multidb-webstack

**A modern local web development stack for Linux Mint:**
Run PHP, Python, Node, and Go apps in Docker containers, while all databases (MySQL, PostgreSQL, MongoDB, Redis, etc.) run natively on your host for maximum performance and realism. Includes ready-to-use templates for Laravel, FastAPI, React, and Golang, with Traefik for local domain routing.

---

## Local Database Installation

For scripts and instructions to install and configure MySQL, PostgreSQL, MongoDB, and Redis on Linux Mint, see the reference repository:

> [inversemaha/linuxmint-multidb-webstack](https://github.com/inversemaha/linuxmint-multidb-webstack)

---

A professional local development environment where **Docker runs app containers only** and **all databases run natively on the host machine**.

---

## Philosophy

```
Docker         =  App runtimes ONLY (PHP, Python, Node, Go)
Local machine  =  All databases (MySQL, PostgreSQL, MongoDB, Redis)
Traefik        =  Local domain routing (*.local)
```

**Why not databases in Docker?**
- Better disk I/O performance (no volume overhead)
- Easier debugging with native CLI tools
- No data loss from accidental `docker compose down -v`
- Single DB instance shared across projects
- Mirrors production architecture (app servers separate from DB servers)

---

## Repository Structure

```
LOCAL-MACHINE-SETUP-LINUX-MINT/
├── setup_local_machine.sh          # Install Docker + NVM (one-time)
├── setup_projectwise_template.sh   # Generate project from template (main script)
├── Makefile.sh                     # Universal project commands
├── projectwise_template_arg/       # Alternative: command-line arg version
│   ├── setup_projectwise_template.sh
│   └── README.md
├── projectwise_template_menu/      # Alternative: interactive menu version
│   ├── setup_projectwise_template.sh
│   └── README.md
└── README.md                       # This file
```

### Generated Workspace Structure

Running `setup_projectwise_template.sh <type> <name>` creates:

```
/media/bot/INT-LOCAL/docker-dev-workspace/
├── docker/
│   └── traefik/                    # Shared reverse proxy (start once)
│       ├── docker-compose.yml
│       └── traefik.yml
│
└── projects/                       # All projects organized by type
    ├── laravel/
    │   └── <project-name>/         # e.g. my-blog
    │       ├── docker-compose.yml
    │       ├── Dockerfile
    │       ├── .env / .env.example
    │       ├── supervisord.conf
    │       └── nginx/default.conf
    ├── fastapi/
    │   └── <project-name>/         # e.g. blog
    │       ├── docker-compose.yml
    │       ├── Dockerfile
    │       ├── .env / .env.example
    │       └── main.py
    ├── react/
    │   └── <project-name>/         # e.g. dashboard
    │       ├── docker-compose.yml
    │       ├── Dockerfile
    │       ├── .env / .env.example
    └── golang/
        └── <project-name>/         # e.g. api-gateway
            ├── docker-compose.yml
            ├── Dockerfile
            ├── .env / .env.example
```

---

## What Each Template Generates

| Type | Base Image | Files Created | DB Support |
|------|-----------|---------------|------------|
| **Laravel** | `php:8.3-fpm` | Dockerfile, docker-compose.yml, supervisord.conf, nginx/default.conf, .env | MySQL + Redis |
| **FastAPI** | `python:3.13-slim` | Dockerfile, docker-compose.yml, main.py, .env | PostgreSQL + MongoDB + Redis |
| **React** | `node:24-alpine` | Dockerfile, docker-compose.yml, .env | None (frontend only) |
| **Golang** | `golang:1.22-alpine` | Dockerfile, docker-compose.yml, .env | PostgreSQL + Redis |

All templates include:
- `{{PROJECT_NAME}}` placeholder auto-replacement
- `.env` auto-generated from `.env.example`
- `host.docker.internal` for DB connectivity
- Traefik labels for `<project-name>.local` domain routing
- `traefik_net` external network

---

## Additional Template Versions

Three identical template scripts (same output, different input method):

| Script | Input Method | Usage |
|--------|-------------|-------|
| `./setup_projectwise_template.sh` (root) | CLI args | `./setup_projectwise_template.sh fastapi blog` |
| `projectwise_template_arg/` | CLI args | `./setup_projectwise_template.sh fastapi blog` |
| `projectwise_template_menu/` | Interactive menu | `./setup_projectwise_template.sh` then select |

Each folder contains its own README.md and setup script.

---

## Getting Started

### Step 1: Setup Host Machine (one-time)

```bash
chmod +x setup_local_machine.sh
./setup_local_machine.sh
```

Installs: Docker CE, Docker Compose plugin, NVM.

> **Important:** Logout and login after running this for Docker group permissions.

```bash
docker --version
docker compose version
```

### Step 2: Generate a Project

```bash
chmod +x setup_projectwise_template.sh
./setup_projectwise_template.sh fastapi blog
./setup_projectwise_template.sh laravel my-blog
./setup_projectwise_template.sh react dashboard
./setup_projectwise_template.sh golang api-gateway
```

This creates a ready project at `/media/bot/INT-LOCAL/docker-dev-workspace/projects/<type>/<name>/`
with all `{{PROJECT_NAME}}` placeholders replaced and `.env` auto-generated.

### Step 3: Create the Database

The setup script does NOT create the actual database — create it on your host:

```bash
# PostgreSQL
sudo -u postgres createdb blog

# MySQL
mysql -u root -p -e "CREATE DATABASE my_blog;"

# MongoDB (auto-creates on first write, no action needed)
```

### Step 4: Configure Local Domains

```bash
sudo sh -c 'echo "127.0.0.1 blog.local my-blog.local dashboard.local api-gateway.local" >> /etc/hosts'
```

### Step 5: Start Traefik

```bash
cd /media/bot/INT-LOCAL/docker-dev-workspace/docker/traefik
docker compose up -d
```

Dashboard: http://localhost:8080

### Step 6: Start Your Project

```bash
cd /media/bot/INT-LOCAL/docker-dev-workspace/projects/fastapi/blog
nano .env          # Edit DB credentials if needed
docker compose up -d --build
```

---

## How Containers Connect to Local Databases

All docker-compose files include:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

This maps `host.docker.internal` inside the container to your host machine's IP. App configs use it as the DB host:

```env
# Laravel
DB_HOST=host.docker.internal

# FastAPI
DATABASE_URL=postgresql://postgres:root@host.docker.internal:5432/blog

# Golang
DATABASE_URL=postgresql://postgres:root@host.docker.internal:5432/api-gateway
```

> **Prerequisite:** Your local databases must listen on `0.0.0.0` (not just `127.0.0.1`).
> See the workspace README at `/media/bot/INT-LOCAL/docker-dev-workspace/README.md` for detailed bind-address configuration.

---

## Using the Makefile

Copy `Makefile.sh` to the workspace as `Makefile`, or use it from this repo.

### Syntax: `make <command> P=<type>/<name>`

> **Important:** The `P=` parameter uses the format `<type>/<name>` matching the project path structure.

### Docker Compose

| Command | Description |
|---------|-------------|
| `make up P=fastapi/blog` | Build & start project |
| `make start P=fastapi/blog` | Start (no rebuild) |
| `make stop P=fastapi/blog` | Stop containers |
| `make down P=fastapi/blog` | Remove containers |
| `make restart P=fastapi/blog` | Stop + rebuild + start |
| `make ps P=fastapi/blog` | Show container status |
| `make logs P=fastapi/blog` | Follow all logs |
| `make logs-app P=fastapi/blog` | Follow app container logs |

### Shell Access

| Command | Description |
|---------|-------------|
| `make shell P=fastapi/blog` | Open `sh` in app container |
| `make bash P=laravel/my-blog` | Open `bash` in app container |

### Traefik

| Command | Description |
|---------|-------------|
| `make traefik-up` | Start Traefik |
| `make traefik-down` | Stop Traefik |
| `make traefik-logs` | Follow Traefik logs |

### Laravel / PHP

| Command | Description |
|---------|-------------|
| `make migrate P=laravel/my-blog` | Run migrations |
| `make migrate-fresh P=laravel/my-blog` | Fresh migrate + seed |
| `make seed P=laravel/my-blog` | Run seeders |
| `make artisan P=laravel/my-blog CMD="route:list"` | Any artisan command |
| `make composer P=laravel/my-blog CMD="require sanctum"` | Any composer command |

### FastAPI / Python

| Command | Description |
|---------|-------------|
| `make test P=fastapi/blog` | Run pytest |
| `make pip P=fastapi/blog CMD="install pandas"` | Run pip |
| `make python P=fastapi/blog CMD="manage.py"` | Run python |

### React / Node

| Command | Description |
|---------|-------------|
| `make install P=react/dashboard` | npm install |
| `make build P=react/dashboard` | npm run build |
| `make dev P=react/dashboard` | npm run dev |
| `make npm P=react/dashboard CMD="run lint"` | Any npm command |

### Golang

| Command | Description |
|---------|-------------|
| `make go-run P=golang/api-gw` | go run . |
| `make go-build P=golang/api-gw` | go build |
| `make go-test P=golang/api-gw` | go test ./... |

### Utility

| Command | Description |
|---------|-------------|
| `make list` | List all projects & templates |
| `make clean` | Prune unused Docker resources |
| `make clean-all` | Full Docker cleanup (images too) |

---

## Architecture

### Laravel Stack

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Traefik   │────▶│    Nginx    │────▶│  PHP-FPM    │
│   :80       │     │   :80       │     │   :9000     │
└─────────────┘     └─────────────┘     └──────┬──────┘
                          Docker                │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┼ ─ ─ ─
                       Local Machine            │
                      ┌─────────────┐    ┌──────┴──────┐
                      │    Redis    │    │    MySQL    │
                      │   :6379    │    │   :3306    │
                      └─────────────┘    └─────────────┘
```

### FastAPI Stack

```
┌─────────────┐     ┌─────────────┐
│   Traefik   │────▶│   FastAPI   │
│   :80       │     │   Uvicorn   │
└─────────────┘     └──────┬──────┘
                     Docker │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┼ ─ ─ ─ ─ ─ ─ ─ ─ ─
                  Local Machine
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐  ┌─────────┐  ┌─────────┐
        │PostgreSQL│  │ MongoDB │  │  Redis  │
        │  :5432   │  │ :27017  │  │  :6379  │
        └──────────┘  └─────────┘  └─────────┘
```

### React Stack

```
┌─────────────┐     ┌─────────────┐
│   Traefik   │────▶│    Vite     │
│   :80       │     │   :5173     │
└─────────────┘     └─────────────┘
                      (no DB needed)
```

### Golang Stack

```
┌─────────────┐     ┌─────────────┐
│   Traefik   │────▶│   Go App   │
│   :80       │     │   :8090     │
└─────────────┘     └──────┬──────┘
                     Docker │
─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┼ ─ ─ ─ ─ ─ ─
                  Local Machine
              ┌────────────┴────────────┐
              ▼                         ▼
        ┌──────────┐             ┌─────────┐
        │PostgreSQL│             │  Redis  │
        │  :5432   │             │  :6379  │
        └──────────┘             └─────────┘
```

---

## Troubleshooting

### Docker Permission Denied

Logout and login after `setup_local_machine.sh`, or:

```bash
newgrp docker
```

### Port Already in Use

```bash
sudo lsof -i :80
sudo systemctl stop apache2 nginx  # if conflicting
```

### Container Can't Reach Local DB

1. Check DB is listening on `0.0.0.0`:
   ```bash
   sudo ss -tlnp | grep -E '3306|5432|27017|6379'
   ```
2. Check DB allows connections from Docker subnet (`172.x.x.x`)
3. Test from inside container:
   ```bash
   docker compose exec app sh
   # PostgreSQL test:
   apt-get update && apt-get install -y postgresql-client
   psql -h host.docker.internal -U postgres -d blog
   ```

### Changes Not Reflecting

Rebuild after Dockerfile changes:

```bash
docker compose down
docker compose up -d --build
```

### Complete Reset

```bash
cd projects/fastapi/blog && docker compose down
cd ../../../docker/traefik && docker compose down
docker system prune -f
```

---

## Project Structure and Traefik Usage

- All projects are created under:
  ```
  projects/<project-type>/<project-name>/
  ```
  Example: `projects/fastapi/blog/`, `projects/laravel/my-blog/`
- Traefik (local domain reverse proxy) lives at:
  ```
  docker/traefik/
  ```
- Traefik is shared for all projects. Start it once, and all your projects are accessible via their local domains (e.g., `blog.local`, `my-blog.local`).
- See the workspace README at `/media/bot/INT-LOCAL/docker-dev-workspace/README.md` for detailed step-by-step project management instructions.
