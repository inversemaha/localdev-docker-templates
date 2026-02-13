# Clean Engineering Local Environment

A professional, containerized local development environment for full-stack engineering teams. This template provides isolated Docker-based development stacks for **Laravel (PHP)**, **FastAPI (Python)**, and **React (Node.js)** projects while keeping your host machine completely clean.

All dependencies, databases, and services run inside containers. Your host only needs Docker and Make.

---

## Features

- **100% Containerized** — Zero host dependencies, no version conflicts
- **Local Domains** — Access projects via `laravel.local`, `fastapi.local`, `react.local` using Traefik
- **Hot Reload** — Live code synchronization with Docker volumes
- **Background Workers** — Laravel Queue workers with Supervisor
- **Managed Databases** — MySQL, PostgreSQL, MongoDB, Redis per project
- **Universal Makefile** — Single command interface for all projects
- **Network Isolation** — Per-project networks with shared Traefik reverse proxy

---

## Repository Structure

```
LOCAL-MACHINE-SETUP-LINUX-MINT/
├── setup_local_machine.sh          # Host machine setup (Docker, NVM)
├── setup_projectwise_template.sh   # Generate project templates
├── Makefile.sh                     # Universal project commands
└── README.md                       # This file
```

### Generated Output Structure

Running `setup_projectwise_template.sh` generates a complete project workspace at `/media/bot/INT-LOCAL/docker-dev-workspace/` with the following structure:

```
docker-dev-workspace/   # ⚠️ Generated output — not part of this repo
├── .env.example                    # Environment variables template
├── README.md                       # Generated project README
│
├── docker/
│   └── traefik/
│       ├── docker-compose.yml      # Traefik reverse proxy
│       └── traefik.yml             # Traefik static configuration
│
└── projects/
    ├── laravel/
    │   ├── Dockerfile              # PHP 8.3-FPM with extensions
    │   ├── docker-compose.yml      # Nginx, PHP-FPM, MySQL, Redis
    │   ├── supervisord.conf        # Queue worker configuration
    │   └── nginx/
    │       └── default.conf        # Nginx virtual host
    │
    ├── fastapi/
    │   ├── Dockerfile              # Python 3.11 with ML libraries
    │   └── docker-compose.yml      # FastAPI, PostgreSQL, MongoDB
    │
    └── react/
        ├── Dockerfile              # Node 20 with Vite
        └── docker-compose.yml      # React development server
```

---

## Getting Started

### Step 1: Setup Host Machine

Run the system setup script to install Docker, Docker Compose, and NVM:

```bash
chmod +x setup_local_machine.sh
./setup_local_machine.sh
```

This script will:

- Install Docker CE and Docker Compose plugin
- Add your user to the `docker` group
- Install NVM (Node Version Manager)

> **Important:** After the script completes, logout and login again (or reboot) for Docker group changes to take effect.

Verify installation:

```bash
docker --version
docker compose version
```

### Step 2: Setup Project Template

Generate the project structure and configuration files:

```bash
chmod +x setup_projectwise_template.sh
./setup_projectwise_template.sh
```

This creates:

- Project folders with Docker configurations
- Traefik reverse proxy setup
- Environment template file

Copy the environment file and adjust ports if needed:

```bash
cp .env.example .env
```

Default ports:

| Service    | Port  |
|------------|-------|
| Laravel    | 8080  |
| FastAPI    | 8000  |
| React      | 5173  |
| MySQL      | 3307  |
| PostgreSQL | 5432  |
| MongoDB    | 27017 |

### Step 3: Configure Local Domains

Add the following entries to your `/etc/hosts` file:

```bash
sudo nano /etc/hosts
```

Add this line:

```
127.0.0.1 laravel.local fastapi.local react.local
```

Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

### Step 4: Start Traefik Reverse Proxy

Start the Traefik container before running projects:

```bash
make traefik-up
```

Access the Traefik dashboard at: http://localhost:8080

---

## Using the Makefile

The Makefile provides a dynamic interface for managing any project without modification.

### Core Variables

| Variable       | Description            | Default                        |
|----------------|------------------------|--------------------------------|
| `PROJECT_PATH` | Path to project folder | `.` (current directory)        |
| `CONTAINER`    | Target container name  | Auto-detected based on project |

### Global Commands

Start a project (build if needed):

```bash
make up PROJECT_PATH=projects/laravel
make up PROJECT_PATH=projects/fastapi
make up PROJECT_PATH=projects/react
```

Start existing containers (no build):

```bash
make start PROJECT_PATH=projects/laravel
```

Stop containers:

```bash
make stop PROJECT_PATH=projects/laravel
```

Remove containers:

```bash
make down PROJECT_PATH=projects/laravel
```

View logs:

```bash
make logs PROJECT_PATH=projects/laravel
```

Access container shell:

```bash
make bash PROJECT_PATH=projects/laravel
# or
make shell PROJECT_PATH=projects/fastapi  # Uses sh instead of bash
```

Check container status:

```bash
make ps PROJECT_PATH=projects/laravel
```

### Laravel-Specific Commands

Run database migrations:

```bash
make migrate PROJECT_PATH=projects/laravel
```

Fresh migration with seeders:

```bash
make migrate-fresh PROJECT_PATH=projects/laravel
```

Seed database:

```bash
make seed PROJECT_PATH=projects/laravel
```

Run Artisan commands:

```bash
make artisan PROJECT_PATH=projects/laravel CMD="route:list"
make artisan PROJECT_PATH=projects/laravel CMD="tinker"
```

Run Composer commands:

```bash
make composer PROJECT_PATH=projects/laravel CMD="install"
make composer PROJECT_PATH=projects/laravel CMD="require laravel/sanctum"
```

### FastAPI-Specific Commands

Run pytest:

```bash
make test PROJECT_PATH=projects/fastapi
```

Install Python packages:

```bash
make pip PROJECT_PATH=projects/fastapi CMD="install pandas numpy"
```

### React-Specific Commands

Install NPM packages:

```bash
make install PROJECT_PATH=projects/react
```

Run development server:

```bash
make dev PROJECT_PATH=projects/react
```

Build for production:

```bash
make build PROJECT_PATH=projects/react
```

Run NPM scripts:

```bash
make npm PROJECT_PATH=projects/react CMD="run lint"
make npm PROJECT_PATH=projects/react CMD="run test"
```

### Traefik Commands

Start Traefik:

```bash
make traefik-up
```

Stop Traefik:

```bash
make traefik-down
```

View Traefik logs:

```bash
make traefik-logs
```

---

## Accessing Your Applications

Once projects are running, access them via:

| Project           | Local Domain             | Container Direct Port    |
|-------------------|--------------------------|--------------------------|
| Laravel           | http://laravel.local      | http://localhost:8080     |
| FastAPI           | http://fastapi.local      | http://localhost:8000     |
| React             | http://react.local        | http://localhost:5173     |
| Traefik Dashboard | —                        | http://localhost:8080     |

---

## Architecture Overview

### Laravel Stack

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Traefik   │────▶│    Nginx    │────▶│  PHP-FPM    │
│   :80       │     │   :80       │     │   :9000     │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                      ┌─────────────┐    ┌─────┴─────┐
                      │    Redis    │    │   MySQL   │
                      │   :6379    │    │   :3306   │
                      └─────────────┘    └───────────┘
```

**Components:**

- **Nginx** — Web server handling HTTP requests
- **PHP-FPM** — PHP processor with extensions (PDO, Redis, GD, Xdebug)
- **Supervisor** — Manages PHP-FPM and Queue Workers
- **MySQL** — Database server
- **Redis** — Cache and session store

### FastAPI Stack

```
┌─────────────┐     ┌─────────────┐
│   Traefik   │────▶│   FastAPI   │
│   :80       │     │   Uvicorn   │
└─────────────┘     └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐  ┌─────────┐  ┌─────────┐
        │PostgreSQL│  │ MongoDB │  │  Redis  │
        │  :5432   │  │ :27017  │  │  :6379  │
        └──────────┘  └─────────┘  └─────────┘
```

**Components:**

- **FastAPI** — Python ASGI application
- **Uvicorn** — ASGI server
- **PostgreSQL** — Relational database
- **MongoDB** — Document database
- **Pre-installed ML libs** — pandas, numpy, scikit-learn, torch, transformers

### React Stack

```
┌─────────────┐     ┌─────────────┐
│   Traefik   │────▶│    Vite     │
│   :80       │     │   :5173     │
└─────────────┘     └─────────────┘
```

**Components:**

- **Vite** — Next-generation frontend tooling
- **Node 20** — JavaScript runtime
- **Hot Module Replacement** — Instant code updates

---

## Best Practices

### Host Machine Cleanliness

- No PHP, Python, Node, or database servers installed on host
- All development tools run inside containers
- Version conflicts eliminated through isolation

### Project Isolation

- Each project has independent containers and networks
- Database data persists in named volumes
- Projects can run simultaneously without port conflicts

### Containerized Dependencies

- **Laravel:** PHP 8.3, Composer, extensions locked in Dockerfile
- **FastAPI:** Python 3.11, specific package versions in requirements
- **React:** Node 20, NPM packages in container image

### Extensibility

Add new projects by:

1. Creating a `projects/newproject/` folder
2. Adding `Dockerfile` and `docker-compose.yml`
3. Adding Traefik labels for routing
4. Updating the Makefile with project-specific commands (optional)

### Version Control Friendly

- No build artifacts or dependencies in repository
- Environment variables in `.env` (gitignored)
- Only configuration and scripts committed

---

## Troubleshooting

### Docker Permission Denied

**Error:** `permission denied while trying to connect to Docker daemon`

**Solution:** Logout and login again after running `setup_local_machine.sh`, or run:

```bash
newgrp docker
```

### Port Already in Use

**Error:** `bind: address already in use`

**Solution:** Check what's using the port:

```bash
sudo lsof -i :80
sudo lsof -i :8080
```

Stop conflicting services:

```bash
sudo systemctl stop apache2
sudo systemctl stop nginx
```

### Container Not Found

**Error:** `No such container: laravel_app`

**Solution:** Ensure containers are built and running:

```bash
make up PROJECT_PATH=projects/laravel
```

### Changes Not Reflecting

**Solution:** Rebuild containers after Dockerfile changes:

```bash
make down PROJECT_PATH=projects/laravel
make up PROJECT_PATH=projects/laravel
```

### Laravel Storage Permission Errors

**Solution:** Fix permissions inside container:

```bash
make bash PROJECT_PATH=projects/laravel
chmod -R 777 storage bootstrap/cache
exit
```

### Network Connectivity Issues

Recreate the shared Traefik network:

```bash
make traefik-down
docker network rm traefik_net
docker network create traefik_net
make traefik-up
```

### Complete Reset

Stop everything and clean Docker:

```bash
# Stop all projects
make down PROJECT_PATH=projects/laravel
make down PROJECT_PATH=projects/fastapi
make down PROJECT_PATH=projects/react
make traefik-down

# Clean Docker system
make clean        # Remove unused containers/networks
make clean-all    # Full cleanup including volumes (WARNING: data loss)
```

---

## Environment Variables

Create `.env` file from `.env.example`:

```bash
cp .env.example .env
```

Available variables:

```bash
# Application Ports (host side)
LARAVEL_PORT=8080
FASTAPI_PORT=8000
REACT_PORT=5173

# Database Ports (host side)
MYSQL_PORT=3307
POSTGRES_PORT=5432
MONGO_PORT=27017
```

---

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Commit changes: `git commit -am 'Add new feature'`
4. Push to branch: `git push origin feature/new-feature`
5. Submit Pull Request

---

## License

MIT License — see `LICENSE` file for details.

<p align="center">
  Built for engineers who value clean, reproducible development environments.
</p>
