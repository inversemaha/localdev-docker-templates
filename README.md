# 🚀 Docker Development Workspace - MEMAHA Branch

**A streamlined Docker development workspace generator** that simplifies the creation of multi-project development environments. It follows the philosophy of keeping applications in Docker containers while databases run on the host machine for better performance and easier management.

## ✨ Features

- **Interactive & Automated Menu System** - Easy project selection with numeric input (1-5)
- **Multiple Project Types** - Laravel, FastAPI, React, Go with auto-port assignment
- **Automatic Traefik Integration** - Auto-configures reverse proxy for clean local domains
- **Auto DNS Management** - Automatically adds `project.local` entries to `/etc/hosts`
- **Smart Port Assignment** - Automatically finds available ports (FastAPI: 8000+, React: 3000+, etc.)
- **Host-based Databases** - PostgreSQL, MySQL, Redis run on host for optimal performance
- **Multiple Projects Support** - All projects can run simultaneously with unique domains
- **Development-First** - Hot reloading, volume mounts, and debugging support
- **Makefile Automation** - Auto-copied management scripts for easy project control

## 🏗️ Architecture Philosophy

```mermaid
graph TB
    A[Local Machine] --> B[Docker Containers - Apps Only]
    A --> C[Host Services - Databases]
    A --> D[Traefik Proxy]
    
    B --> E[FastAPI Container]
    B --> F[React Container]
    B --> G[Go Container]
    
    C --> H[PostgreSQL]
    C --> I[MySQL]  
    C --> J[Redis]
    
    D --> K[project1.local]
    D --> L[project2.local]
    D --> M[api.local]
    
    E -.->|host.docker.internal| H
    F -.->|API calls| E
    G -.->|host.docker.internal| H
```

### Why This Architecture?

- **🔥 Performance**: Direct database connections without Docker networking overhead
- **💾 Data Persistence**: Databases persist across container rebuilds
- **🔧 Easy Management**: Use native database tools and GUI clients
- **🌐 Clean URLs**: Each project gets its own `.local` domain
- **⚡ Fast Rebuilds**: Only application containers need rebuilding

## 🚀 Quick Start

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

### Step 2: Installation

```bash
# Clone the repository and switch to memaha branch
git clone <repository-url>
cd localdev-docker-templates
git checkout memaha

# Make scripts executable  
chmod +x menu.sh
chmod +x Makefile.sh
chmod +x setup_local_machine.sh
```

### Step 3: Create Your First Project

**Interactive Mode:**
```bash
./menu.sh
# Select project type by number (1-5):
# 1) fastapi
# 2) laravel  
# 3) react
# 4) golang
# 5) quit
# Enter project name when prompted
```

**Automated Mode:**
```bash
# Create FastAPI project non-interactively
echo -e "1\nmy-api-project" | ./menu.sh

# Create React project 
echo -e "3\nmy-frontend" | ./menu.sh
```

### Step 4: Start Your Project

```bash
# Start Traefik (first time only)
cd /media/bot/INT-LOCAL1/docker-dev-workspace/docker/traefik
docker compose up -d

# Start your project
cd ../projects/fastapi/my-api-project
docker compose up -d --build

# Access your app
curl http://my-api-project.local
# or visit: http://my-api-project.local in browser
```

## ✅ Verify Installation Works

```bash
# Test script functionality
echo -e "1\ntest-verification" | ./menu.sh

# Start the test project
cd /media/bot/INT-LOCAL1/docker-dev-workspace/projects/fastapi/test-verification
docker compose up -d --build

# Verify it works
curl http://test-verification.local
# Should return: {"status":"running","message":"App is connected to local databases"}
```

## 📋 What Each Template Generates

| Type | Base Image | Files Created | DB Support | Port Range |
|------|-----------|---------------|-----------|------------|
| **Laravel** | `php:8.3-fpm` | Dockerfile, docker-compose.yml, supervisord.conf, nginx/default.conf, .env | MySQL + Redis | 9000+ |
| **FastAPI** | `python:3.13-slim` | Dockerfile, docker-compose.yml, main.py, requirements.txt, .env | PostgreSQL + MongoDB + Redis | 8000+ |
| **React** | `node:24-alpine` | Dockerfile, docker-compose.yml, package.json, vite.config.js, .env | None (frontend only) | 3000+ |
| **Golang** | `golang:1.22-alpine` | Dockerfile, docker-compose.yml, main.go, go.mod, .env | PostgreSQL + Redis | 8080+ |

### Complete Template Contents

**All templates automatically include:**
- ✅ **Smart Placeholder Replacement** - `{{PROJECT_NAME}}` auto-replaced throughout
- ✅ **Environment Files** - `.env` auto-generated from `.env.example`  
- ✅ **Host DB Connectivity** - `host.docker.internal` pre-configured
- ✅ **Traefik Integration** - Labels for `<project-name>.local` domain routing
- ✅ **Network Configuration** - `traefik_net` external network setup
- ✅ **Port Management** - Automatic port assignment with conflict detection
- ✅ **Project Registry** - Auto-maintained `.projects_registry` file
- ✅ **DNS Management** - Automatic `/etc/hosts` entries

## 🛠️ Using the Makefile

**Makefile.sh is automatically copied** to your workspace when you run the menu script!

### Project Management Commands

```bash
# Infrastructure Management
./Makefile.sh traefik-up              # Start Traefik proxy
./Makefile.sh traefik-down            # Stop Traefik proxy
./Makefile.sh traefik-logs            # View Traefik logs

# Project Commands  
./Makefile.sh up PROJECT=my-api       # Start specific project
./Makefile.sh down PROJECT=my-api     # Stop specific project
./Makefile.sh logs PROJECT=my-api     # View project logs
./Makefile.sh build PROJECT=my-api    # Rebuild project
./Makefile.sh shell PROJECT=my-api    # Open shell in container

# Workspace Management
./Makefile.sh list                    # List all projects
./Makefile.sh status                  # Show running containers
./Makefile.sh clean                   # Clean unused Docker resources
```

## 🔄 **Traefik Automation**

**The script completely automates Traefik setup and configuration!**

### What Gets Automated
✅ **Traefik Configuration Generation** - Auto-creates `docker-compose.yml` and `traefik.yml`  
✅ **DNS Entry Management** - Automatically adds `project.local` to `/etc/hosts`  
✅ **Dynamic Routing** - Auto-updates Traefik configuration for new projects  
✅ **Service Restart** - Automatically restarts Traefik to load new configurations  
✅ **Port Assignment** - Smart port detection and assignment (FastAPI: 8000+, React: 3000+)  
✅ **Multi-Project Support** - Reuses existing Traefik, no conflicts  

### Automation Flow
```bash
# When you run: echo -e "1\nmy-project" | ./menu.sh
# The script automatically:

1. ✅ Creates project structure
2. ✅ Detects available port (e.g., 8003)  
3. ✅ Updates Traefik routing configuration
4. ✅ Adds "my-project.local" to /etc/hosts
5. ✅ Restarts Traefik to reload config
6. ✅ Shows you the access URL

# Output you'll see:
# "Traefik configuration already exists - reusing for multiple projects ✅"
# "Adding static routing for my-project to Traefik..."
# "Added my-project.local to /etc/hosts"  
# "Traefik restarted successfully"
```

### Zero Manual Configuration Required
- **No manual Traefik setup** - Script handles everything
- **No manual DNS editing** - Automatic `/etc/hosts` management  
- **No port conflicts** - Smart port detection and assignment
- **No routing config** - Dynamic Traefik rule generation

## � Multiple Projects Support

**All scripts support creating and running multiple projects simultaneously!**

### How It Works
- **First project**: Creates shared Traefik configuration  
- **Additional projects**: Reuse existing Traefik (no conflicts)
- **Unique domains**: Each project gets `projectname.local`
- **Independent lifecycle**: Start/stop projects individually
- **Shared dashboard**: View all projects at `localhost:8080`

### Example Multi-Project Setup
```bash
# Create multiple projects using the interactive menu
./menu.sh  # Select FastAPI, name: api-backend
./menu.sh  # Select React, name: web-frontend  
./menu.sh  # Select Laravel, name: admin-panel

# Start Traefik once
cd /media/bot/INT-LOCAL1/docker-dev-workspace/docker/traefik
docker-compose up -d

# Start projects (all run simultaneously) 
cd ../projects/fastapi/api-backend && docker compose up -d
cd ../laravel/admin-panel && docker compose up -d
cd ../react/web-frontend && docker compose up -d

# Access projects
# → http://api-backend.local (FastAPI)
# → http://admin-panel.local (Laravel)
# → http://web-frontend.local (React)
# → http://localhost:8080 (Traefik dashboard)
```

## 🎯 Project Templates

### FastAPI Template

**Features:**
- Python 3.13 with FastAPI, Uvicorn, and comprehensive ML/data stack
- PostgreSQL + MongoDB + Redis connectivity via `host.docker.internal`
- Pre-installed packages: SQLAlchemy, psycopg2-binary, pymongo, motor, redis
- CORS middleware and pydantic-settings pre-configured
- Hot reloading enabled with volume mounts
- Health check endpoints and debugging support

**Auto-created files:**
- `Dockerfile` - Python 3.13-slim with ML/DB dependencies
- `docker-compose.yml` - Traefik-enabled service configuration  
- `main.py` - FastAPI app with database connection examples
- `requirements.txt` - Common packages for API development
- `.env` / `.env.example` - Database and Redis connection strings

**Environment variables:**
```env
APP_PORT=8000  # Auto-assigned unique port
DATABASE_URL=postgresql://postgres:root@host.docker.internal:5432/projectname  
MONGO_URL=mongodb://host.docker.internal:27017/projectname
REDIS_URL=redis://host.docker.internal:6379/0
```

### React Template

**Features:**
- Node.js 24 with Vite build system for fast development
- TypeScript support and modern React development stack
- Hot module replacement (HMR) for instant updates
- Environment-based configuration with VITE_ prefixed variables
- CORS-ready for API integration with backend services
- Pre-configured for production builds with Vite optimization

**Auto-created files:**
- `Dockerfile` - Node.js 24-alpine optimized for development
- `docker-compose.yml` - Traefik-enabled with volume mounts
- `package.json` - React + Vite + TypeScript dependencies
- `vite.config.js` - Vite configuration with host binding
- `.env` / `.env.example` - API URLs and app configuration

**Environment variables:**
```env
APP_PORT=3000  # Auto-assigned unique port (3000+)
VITE_API_URL=http://localhost:8000  # Points to your FastAPI/Laravel backend
VITE_APP_NAME=projectname
```

### Go Template

**Features:**
- Go 1.22 with Alpine Linux for minimal container size
- PostgreSQL and Redis connectivity via `host.docker.internal`
- Environment-based configuration with godotenv
- Hot reloading via volume mounts for rapid development
- Health check endpoints and graceful shutdown handling
- Cross-compilation support for production builds

**Auto-created files:**
- `Dockerfile` - Go 1.22-alpine with build tools
- `docker-compose.yml` - Traefik-enabled service configuration
- `main.go` - Gin web server with database examples
- `go.mod` - Module definition with common dependencies
- `.env` / `.env.example` - Database connection configuration

**Environment variables:**
```env
APP_PORT=8080  # Auto-assigned unique port (8080+)
DATABASE_URL=postgresql://postgres:root@host.docker.internal:5432/projectname
REDIS_URL=redis://host.docker.internal:6379/0
```

### Laravel Template

**Features:**
- PHP 8.3-FPM with Nginx reverse proxy for high performance
- MySQL and Redis connectivity via `host.docker.internal`
- Supervisor for process management (queues, schedulers)
- Composer dependency management and Laravel optimization
- Xdebug support for development debugging
- Queue worker and scheduler support out of the box

**Auto-created files:**
- `Dockerfile` - PHP 8.3-FPM with Laravel extensions
- `docker-compose.yml` - Nginx + PHP-FPM + Traefik configuration
- `supervisord.conf` - Process management for workers
- `nginx/default.conf` - Nginx configuration for Laravel
- `.env` / `.env.example` - MySQL and Redis connection strings

**Environment variables:**
```env
APP_PORT=9000  # Auto-assigned unique port (9000+)
DB_CONNECTION=mysql
DB_HOST=host.docker.internal
DB_PORT=3306
DB_DATABASE=projectname
DB_USERNAME=root
DB_PASSWORD=root
REDIS_HOST=host.docker.internal
REDIS_PORT=6379
QUEUE_CONNECTION=redis
```

## 🗄️ Database Setup

### PostgreSQL

```bash
# Install PostgreSQL (Ubuntu/Debian)
sudo apt update && sudo apt install postgresql postgresql-contrib

# Start service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create user and databases
sudo -u postgres createuser --interactive --pwprompt
sudo -u postgres createdb projectname
```

### MySQL

```bash
# Install MySQL (Ubuntu/Debian)
sudo apt update && sudo apt install mysql-server

# Secure installation
sudo mysql_secure_installation

# Create database
mysql -u root -p
CREATE DATABASE projectname;
```

### Redis

```bash
# Install Redis (Ubuntu/Debian)
sudo apt update && sudo apt install redis-server

# Start service  
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

## 🔧 Configuration

### Environment Variables

Set these in your shell profile (`.bashrc`, `.zshrc`):

```bash
# Workspace location (default: /media/bot/INT-LOCAL1)
export MEMAHA_BASE_DIR="/path/to/your/workspace"

# Workspace name (default: docker-workspace)
export MEMAHA_WORKSPACE="my-development-workspace"
```

### Custom Project Templates

To add new project types, extend the `menu.sh` script:

1. **Add menu option** in `show_menu()` function
2. **Create template function** following naming convention `create_TYPENAME_project()`
3. **Add case** in main menu switch statement
4. **Update README** with template documentation

Example template function structure:

```bash
create_newtype_project() {
    local project_name="$1"
    local project_dir="$WORKSPACE_DIR/projects/newtype/$project_name"
    
    log_info "Creating NewType project: $project_name"
    mkdir -p "$project_dir"
    
    # Create .env, Dockerfile, docker-compose.yml
    # Add template-specific files
    
    log_success "NewType project '$project_name' created successfully"
}
```

## 🚦 Troubleshooting

### Common Issues

1. **"Cannot connect to database"**
   - Ensure database service is running on host
   - Check firewall settings
   - Verify `host.docker.internal` resolution

2. **"Traefik dashboard not accessible"**
   - Ensure port 8080 is not in use
   - Check Docker service status
   - Verify Traefik container is running

3. **"Project.local domain not working"**
   - DNS entries are automatically added to `/etc/hosts`
   - If manual entry needed: `echo '127.0.0.1 projectname.local' | sudo tee -a /etc/hosts`
   - Or use direct port access: `http://localhost:PORT`

4. **"Permission denied" errors**
   - Make scripts executable: `chmod +x menu.sh makefile.sh`
   - Check Docker socket permissions
   - Ensure user is in docker group

5. **"get_next_available_port: command not found"**
   - This indicates a function definition order issue in menu.sh
   - Fixed in current version - update your script

6. **"Menu selection not working"**
   - Use **numeric input** (1, 2, 3, 4, 5) not text ("fastapi", "react")
   - Correct: `echo -e "1\nproject-name" | ./menu.sh`
   - Wrong: `echo -e "fastapi\nproject-name" | ./menu.sh`

### Logs and Debugging

```bash
# View application logs
./makefile.sh logs PROJECT=projectname

# View Traefik logs  
./makefile.sh traefik-logs

# Check container status
docker ps

# Inspect networks
docker network ls
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-template`
3. **Follow coding standards** and existing patterns
4. **Test thoroughly** with different project types
5. **Update documentation** for new features
6. **Submit pull request** with clear description

### Development Guidelines

- **Keep templates minimal** but functional
- **Use environment variables** for configuration
- **Follow Docker best practices** (multi-stage builds, small images)
- **Maintain consistency** across project types
- **Document all options** and environment variables

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **Docker** for containerization platform
- **Traefik** for reverse proxy capabilities
- **FastAPI**, **React**, **Go** communities for excellent frameworks
- **Contributors** who help improve this template system

---

**Happy Coding!** 🎉

For questions, issues, or feature requests, please open an issue on the repository.
