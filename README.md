# linuxmint-multidb-webstack

**A modern local web development stack for Linux Mint:**
Run PHP, Python, Node, and Go apps in Docker containers, while all databases (MySQL, PostgreSQL, MongoDB, Redis, etc.) run natively on your host for maximum performance and realism. Includes ready-to-use templates for Laravel, FastAPI, React, and Golang, with Traefik for local domain routing.

---

## Local Database Installation

For scripts and instructions to install and configure MySQL, PostgreSQL, MongoDB, and Redis on Linux Mint, see the reference repository:

👉 [inversemaha/linuxmint-multidb-webstack](https://github.com/inversemaha/linuxmint-multidb-webstack)

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
├── setup_projectwise_template.sh   # Generate workspace templates
├── Makefile.sh                     # Universal project commands
└── README.md                       # This file
```

### Generated Workspace Structure

Running `setup_projectwise_template.sh` creates:

```
/media/bot/INT-LOCAL/docker-dev-workspace/
├── create_project.sh               # Scaffold new projects from templates
├── README.md                       # Workspace README with DB config guide
│
├── projects/                       # Project templates and your actual projects
│   ├── laravel/                    # Laravel template (used as source for new projects)
│   ├── fastapi/                    # FastAPI template (used as source for new projects)
│   ├── react/                      # React template (used as source for new projects)
│   ├── golang/                     # Golang template (used as source for new projects)
│   ├── traefik/                    # Traefik reverse proxy
│   ├── laravel/<project-name>/     # Your Laravel project instances
│   ├── fastapi/<project-name>/     # Your FastAPI project instances
│   ├── react/<project-name>/       # Your React project instances
│   └── golang/<project-name>/      # Your Golang project instances
│
├── docker/
│   └── traefik/                    # Reverse proxy for local domains
│       ├── docker-compose.yml
│       └── traefik.yml
│
└── projects/                       # Your actual projects (created by create_project.sh)
    ├── my-blog/                    # Example: cloned from laravel template
    ├── ml-api/                     # Example: cloned from fastapi template
    └── dashboard/                  # Example: cloned from react template
```

---

## Additional Template Versions

Two alternative template scripts are available:

- **projectwise_template_arg/**: Uses command-line arguments to select the project type.
- **projectwise_template_menu/**: Uses an interactive menu to select the project type.

Each folder contains its own README.md and setup script. Use these for more flexible or interactive project generation.

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

### Step 2: Generate Workspace Templates

```bash
chmod +x setup_projectwise_template.sh
./setup_projectwise_template.sh
```

### Step 3: Configure Local Domains

```bash
sudo sh -c 'echo "127.0.0.1 my-blog.local ml-api.local dashboard.local" >> /etc/hosts'
```

### Step 4: Start Traefik

```bash
cd /media/bot/INT-LOCAL/docker-dev-workspace
cd docker/traefik && docker compose up -d
```

Dashboard: http://localhost:8080

### Step 5: Create & Run a Project

```bash
cd /media/bot/INT-LOCAL/docker-dev-workspace

# Scaffold from template
./create_project.sh laravel my-blog
./create_project.sh fastapi ml-api
./create_project.sh react dashboard
./create_project.sh golang api-gateway

# Edit DB credentials, then start
cd projects/my-blog
nano .env
docker compose up -d --build
```

---

## How to Select and Generate Individual Project Templates

### Command-line Argument Version (projectwise_template_arg)
1. Navigate to the folder:
   ```bash
   cd projectwise_template_arg
   ```
2. Run the script with your desired project type:
   ```bash
   ./setup_projectwise_template.sh fastapi
   ./setup_projectwise_template.sh laravel
   ./setup_projectwise_template.sh react
   ./setup_projectwise_template.sh golang
   ```
   Only the specified template will be generated.

### Interactive Menu Version (projectwise_template_menu)
1. Navigate to the folder:
   ```bash
   cd projectwise_template_menu
   ```
2. Run the script:
   ```bash
   ./setup_projectwise_template.sh
   ```
3. Select your desired project type (e.g., fastapi, laravel) from the menu.
   Only the selected template will be generated.

### Original Script
1. Navigate to the workspace folder:
   ```bash
   cd LOCAL-MACHINE-SETUP-LINUX-MINT
   ```
2. Run the script with your desired project type:
   ```bash
   ./setup_projectwise_template.sh fastapi
   ./setup_projectwise_template.sh laravel
   ./setup_projectwise_template.sh react
   ./setup_projectwise_template.sh golang
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
DATABASE_URL=postgresql://postgres:root@host.docker.internal:5432/mydb

# Golang
DATABASE_URL=postgresql://postgres:root@host.docker.internal:5432/mydb
```

> **Prerequisite:** Your local databases must listen on `0.0.0.0` (not just `127.0.0.1`).
> See the generated workspace README for detailed bind-address configuration per DB.

---

## Using the Makefile

Copy `Makefile.sh` to the workspace as `Makefile`, or use it from this repo.

### Syntax: `make <command> P=<project-name>`

### Docker Compose

| Command | Description |
|---------|-------------|
| `make up P=my-blog` | Build & start project |
| `make start P=my-blog` | Start (no rebuild) |
| `make stop P=my-blog` | Stop containers |
| `make down P=my-blog` | Remove containers |
| `make restart P=my-blog` | Stop + rebuild + start |
| `make ps P=my-blog` | Show container status |
| `make logs P=my-blog` | Follow all logs |
| `make logs-app P=my-blog` | Follow app container logs |

### Shell Access

| Command | Description |
|---------|-------------|
| `make shell P=my-blog` | Open `sh` in app container |
| `make bash P=my-blog` | Open `bash` in app container |

### Traefik

| Command | Description |
|---------|-------------|
| `make traefik-up` | Start Traefik |
| `make traefik-down` | Stop Traefik |
| `make traefik-logs` | Follow Traefik logs |

### Laravel / PHP

| Command | Description |
|---------|-------------|
| `make migrate P=my-blog` | Run migrations |
| `make migrate-fresh P=my-blog` | Fresh migrate + seed |
| `make seed P=my-blog` | Run seeders |
| `make artisan P=my-blog CMD="route:list"` | Any artisan command |
| `make composer P=my-blog CMD="require sanctum"` | Any composer command |

### FastAPI / Python

| Command | Description |
|---------|-------------|
| `make test P=ml-api` | Run pytest |
| `make pip P=ml-api CMD="install pandas"` | Run pip |
| `make python P=ml-api CMD="manage.py"` | Run python |

### React / Node

| Command | Description |
|---------|-------------|
| `make install P=dashboard` | npm install |
| `make build P=dashboard` | npm run build |
| `make dev P=dashboard` | npm run dev |
| `make npm P=dashboard CMD="run lint"` | Any npm command |

### Golang

| Command | Description |
|---------|-------------|
| `make go-run P=api-gw` | go run . |
| `make go-build P=api-gw` | go build |
| `make go-test P=api-gw` | go test ./... |

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
   make bash P=my-blog
   apt-get update && apt-get install -y default-mysql-client
   mysql -h host.docker.internal -u dev -pdev123
   ```

### Changes Not Reflecting

Rebuild after Dockerfile changes:

```bash
make down P=my-blog
make up P=my-blog
```

### Complete Reset

```bash
make down P=my-blog
make down P=ml-api
make traefik-down
make clean          # Remove unused containers/networks
```

---

## Project Structure and Traefik Usage

- All generated project folders (laravel, fastapi, react, golang) are created under:
  ```
  projects/<project-type>/
  ```
- Traefik (local domain reverse proxy) is created once under:
  ```
  projects/traefik/
  ```
- Traefik is shared for all projects. You do NOT need to create a separate Traefik instance for each project. Just start Traefik once, and all your projects will be accessible via their local domains (e.g., fastapi.local, laravel.local).
