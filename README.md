# 🚀 Docker Development Workspace - MEMAHA Branch

**A streamlined Docker development workspace generator** that simplifies the creation of multi-project development environments. It follows the philosophy of keeping applications in Docker containers while databases run on the host machine for better performance and easier management.

## ✨ Features

- **Interactive Menu System** - Easy project type selection and configuration
- **Multiple Project Types** - Laravel, FastAPI, React, Go
- **Traefik Integration** - Automatic reverse proxy setup for clean local domains
- **Host-based Databases** - PostgreSQL, MySQL, Redis run on host for optimal performance
- **Multiple Projects Support** - All projects can run simultaneously with unique domains
- **Development-First** - Hot reloading, volume mounts, and debugging support

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

## 🚀 Getting Started

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

### Installation

```bash
# Clone the repository and switch to memaha branch
git clone <repository-url>
cd localdev-docker-templates
git checkout memaha

# Make scripts executable  
chmod +x menu.sh
chmod +x Makefile.sh
chmod +x setup_local_machine.sh

# Run the setup
./menu.sh
```

## 📋 What Each Template Generates

| Type | Base Image | Files Created | DB Support |
|------|-----------|---------------|-----------|
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
- Python 3.13 with FastAPI and Uvicorn
- PostgreSQL/MongoDB/Redis connectivity
- CORS middleware pre-configured
- Hot reloading enabled
- Health check endpoints

**Default packages:**
- `fastapi` - Modern web framework
- `uvicorn` - ASGI server  
- `sqlalchemy` - SQL toolkit
- `psycopg2-binary` - PostgreSQL adapter
- `pymongo` + `motor` - MongoDB drivers
- `redis` - Redis client
- `pydantic-settings` - Environment management

**Environment variables:**
```env
DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:5432/projectname
MONGO_URL=mongodb://host.docker.internal:27017/projectname
REDIS_URL=redis://host.docker.internal:6379/0
```

### React Template

**Features:**
- Node.js 20 with Vite build system
- TypeScript support
- Hot module replacement
- Environment-based configuration
- CORS-ready for API integration

**Default packages:**
- `react` + `react-dom` - UI framework
- `vite` - Build tool
- `@vitejs/plugin-react` - React integration
- `typescript` - Type safety

**Environment variables:**
```env
VITE_API_URL=http://localhost:8000
VITE_APP_NAME=projectname
```

### Go Template

**Features:**
- Go 1.21 with Gin web framework
- PostgreSQL and Redis connectivity
- Environment-based configuration
- Health check endpoints
- Hot reloading via volume mounts

**Default packages:**
- `gin-gonic/gin` - Web framework
- `lib/pq` - PostgreSQL driver
- `go-redis/v9` - Redis client
- `godotenv` - Environment loading

**Environment variables:**
```env
DATABASE_URL=postgresql://postgres:postgres@host.docker.internal:5432/projectname
REDIS_URL=redis://host.docker.internal:6379/0
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
   - Add entries to `/etc/hosts`:
     ```
     127.0.0.1 projectname.local
     ```
   - Or use direct port access

4. **"Permission denied" errors**
   - Make scripts executable: `chmod +x menu.sh makefile.sh`
   - Check Docker socket permissions
   - Ensure user is in docker group

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
