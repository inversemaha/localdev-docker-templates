# Projectwise Template (Command-line Argument Version)

Generate Docker development workspaces for specific project types using command-line arguments. **Now supports multiple concurrent projects!**

## Usage

Run the script with project type and project name:

```bash
./setup_projectwise_template.sh <project-type> <project-name>
```

**Available project types:**
- `fastapi` - Python FastAPI with PostgreSQL + MongoDB + Redis
- `laravel` - PHP Laravel with MySQL + Redis  
- `react` - Node.js React with Vite
- `golang` - Go application with PostgreSQL + Redis

## 🚀 Multiple Projects Support

**Create multiple projects that run simultaneously:**

```bash
# Create different projects
./setup_projectwise_template.sh fastapi api-service
./setup_projectwise_template.sh laravel web-app
./setup_projectwise_template.sh react dashboard
./setup_projectwise_template.sh golang microservice
```

**Each project gets unique domain:**
- `http://api-service.local`
- `http://web-app.local` 
- `http://dashboard.local`
- `http://microservice.local`

## Quick Start

1. **Navigate to this folder:**
   ```bash
   cd projectwise_template_arg
   ```

2. **Create your first project:**
   ```bash
   ./setup_projectwise_template.sh fastapi my-api
   ```

3. **Start Traefik (once):**
   ```bash
   cd /media/bot/INT-LOCAL1/docker-dev-workspace/docker/traefik
   docker-compose up -d
   ```

4. **Start your project:**
   ```bash
   cd /media/bot/INT-LOCAL1/docker-dev-workspace/projects/fastapi/my-api
   # Edit .env with your DB settings
   docker compose up -d --build
   ```

5. **Access your project:**
   - 🌐 `http://my-api.local` 
   - 📊 `http://localhost:8080` (Traefik dashboard)

## Advanced Examples

```bash
# E-commerce setup
./setup_projectwise_template.sh laravel shop-backend
./setup_projectwise_template.sh react shop-frontend
./setup_projectwise_template.sh golang payment-service

# Microservices setup
./setup_projectwise_template.sh fastapi user-service
./setup_projectwise_template.sh fastapi order-service
./setup_projectwise_template.sh golang notification-service
./setup_projectwise_template.sh react admin-dashboard
```

## Project Management

**Start individual projects:**
```bash
cd /media/bot/INT-LOCAL1/docker-dev-workspace/projects/<type>/<name>
docker compose up -d
```

**Stop individual projects:**
```bash
cd /media/bot/INT-LOCAL1/docker-dev-workspace/projects/<type>/<name>
docker compose down
```

**View all running projects:**
- Visit `http://localhost:8080` (Traefik dashboard)
