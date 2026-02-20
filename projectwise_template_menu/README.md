# Projectwise Template (Interactive Menu Version)

Generate Docker development workspaces using an interactive menu system. **Now supports multiple concurrent projects!**

## Usage

Run the script and select project type from the menu:

```bash
./setup_projectwise_template.sh
```

**Available project types:**
- `fastapi` - Python FastAPI with PostgreSQL + MongoDB + Redis
- `laravel` - PHP Laravel with MySQL + Redis  
- `react` - Node.js React with Vite
- `golang` - Go application with PostgreSQL + Redis

## 🚀 Multiple Projects Support

**Create multiple projects interactively:**

1. Run script multiple times
2. Select different project types  
3. Enter unique project names
4. All projects run simultaneously with unique domains

## Quick Start

1. **Navigate to this folder:**
   ```bash
   cd projectwise_template_menu
   ```

2. **Create your first project:**
   ```bash
   ./setup_projectwise_template.sh
   ```
   
   **Interactive prompts:**
   ```
   1) fastapi
   2) laravel  
   3) react
   4) golang
   5) quit
   Select the project type: 1
   Enter your project name: blog-api
   ```

3. **Start Traefik (once):**
   ```bash
   cd /media/bot/INT-LOCAL1/docker-dev-workspace/docker/traefik
   docker-compose up -d
   ```

4. **Start your project:**
   ```bash
   cd /media/bot/INT-LOCAL1/docker-dev-workspace/projects/fastapi/blog-api
   # Edit .env with your DB settings
   docker compose up -d --build
   ```

5. **Access your project:**
   - 🌐 `http://blog-api.local` 
   - 📊 `http://localhost:8080` (Traefik dashboard)

## Create Multiple Projects

**Run the script multiple times to create a full stack:**

```bash
# First project
./setup_projectwise_template.sh
# Select: 2) laravel, Name: shop-backend

# Second project  
./setup_projectwise_template.sh
# Select: 3) react, Name: shop-frontend

# Third project
./setup_projectwise_template.sh  
# Select: 4) golang, Name: payment-api
```

**Result:**
- `http://shop-backend.local` - Laravel backend
- `http://shop-frontend.local` - React frontend  
- `http://payment-api.local` - Golang API
- `http://localhost:8080` - Traefik dashboard

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

**Monitor all projects:**
- Visit `http://localhost:8080` for Traefik dashboard
- See all active projects and their health status
