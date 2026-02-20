#!/bin/bash
set -e

# ==============================================================================
#  MEMAHA Makefile - Automation Commands for Docker Workspace
# ==============================================================================
#  Usage: ./Makefile.sh [command] [parameters]
#
#  This Makefile provides convenient automation for managing Docker projects
#  in the MEMAHA workspace environment. It supports multiple project types
#  and provides both project-specific and infrastructure management commands.
# ==============================================================================

# ------------------------------
# CONFIGURATION
# ------------------------------
WORKSPACE_DIR="/media/bot/INT-LOCAL1/docker-dev-workspace"
TRAEFIK_DIR="$WORKSPACE_DIR/docker/traefik"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------------------
# UTILITY FUNCTIONS
# ------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_header() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  🚀 MEMAHA Makefile - Docker Workspace Automation${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

show_usage() {
    show_header
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo -e "${YELLOW}Infrastructure Management:${NC}"
    echo "  traefik-up              Start Traefik reverse proxy"
    echo "  traefik-down            Stop Traefik reverse proxy"
    echo "  traefik-restart         Restart Traefik reverse proxy"
    echo "  traefik-logs            View Traefik logs"
    echo "  traefik-status          Show Traefik status"
    echo ""
    echo -e "${YELLOW}Project Management:${NC}"
    echo "  up PROJECT=<name>       Start project containers"
    echo "  down PROJECT=<name>     Stop project containers"
    echo "  restart PROJECT=<name>  Restart project containers"
    echo "  build PROJECT=<name>    Build project containers"
    echo "  logs PROJECT=<name>     Show project logs"
    echo "  shell PROJECT=<name>    Open shell in project container"
    echo ""
    echo -e "${YELLOW}Workspace Management:${NC}"
    echo "  list                    List all projects"
    echo "  status                  Show running containers"
    echo "  clean                   Clean unused Docker resources"
    echo "  clean-all               Deep clean Docker system"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 up PROJECT=my-api"
    echo "  $0 logs PROJECT=my-frontend"
    echo "  $0 traefik-up"
    echo ""
}

find_project_dir() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        log_error "Project name is required"
        return 1
    fi
    
    # Search in all project type directories
    for project_type in laravel fastapi react golang; do
        local project_dir="$WORKSPACE_DIR/projects/$project_type/$project_name"
        if [[ -d "$project_dir" && -f "$project_dir/docker-compose.yml" ]]; then
            echo "$project_dir"
            return 0
        fi
    done
    
    log_error "Project '$project_name' not found in workspace"
    log_info "Available projects:"
    list_projects
    return 1
}

validate_workspace() {
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        log_error "Workspace directory not found: $WORKSPACE_DIR"
        log_info "Run menu.sh to create projects first"
        return 1
    fi
    return 0
}

# ------------------------------
# INFRASTRUCTURE COMMANDS
# ------------------------------
traefik_up() {
    log_info "Starting Traefik reverse proxy..."
    
    if [[ ! -f "$TRAEFIK_DIR/docker-compose.yml" ]]; then
        log_error "Traefik configuration not found at: $TRAEFIK_DIR"
        log_info "Run menu.sh to set up Traefik first"
        return 1
    fi
    
    cd "$TRAEFIK_DIR"
    docker compose up -d
    
    log_success "Traefik started successfully"
    echo "  🎛️  Dashboard: http://localhost:8080"
    echo "  📁 Location: $TRAEFIK_DIR"
}

traefik_down() {
    log_info "Stopping Traefik reverse proxy..."
    
    if [[ ! -f "$TRAEFIK_DIR/docker-compose.yml" ]]; then
        log_warning "Traefik configuration not found"
        return 0
    fi
    
    cd "$TRAEFIK_DIR"
    docker compose down
    
    log_success "Traefik stopped successfully"
}

traefik_restart() {
    log_info "Restarting Traefik reverse proxy..."
    traefik_down
    sleep 2
    traefik_up
}

traefik_logs() {
    log_info "Showing Traefik logs..."
    
    if [[ ! -f "$TRAEFIK_DIR/docker-compose.yml" ]]; then
        log_error "Traefik configuration not found"
        return 1
    fi
    
    cd "$TRAEFIK_DIR"
    docker compose logs -f
}

traefik_status() {
    log_info "Traefik status:"
    
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "traefik"; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep traefik
        echo ""
        echo "  🌐 Dashboard: http://localhost:8080"
    else
        log_warning "Traefik is not running"
    fi
}

# ------------------------------
# PROJECT COMMANDS
# ------------------------------
project_up() {
    local project_name="$1"
    local project_dir
    
    project_dir=$(find_project_dir "$project_name")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    log_info "Starting project: $project_name"
    log_info "Location: $project_dir"
    
    cd "$project_dir"
    
    # Ensure Traefik network exists (create if not)
    if ! docker network ls | grep -q "traefik_net"; then
        log_info "Creating traefik_net network..."
        docker network create traefik_net
    fi
    
    docker compose up -d --build
    
    log_success "Project '$project_name' started successfully"
    
    # Try to determine the local domain
    if [[ -f "docker-compose.yml" ]]; then
        if grep -q "traefik.http.routers" docker-compose.yml; then
            local domain=$(grep -o "Host(\`[^']*\`)" docker-compose.yml | sed 's/Host(\`\([^']*\`\)/\1/' | tr -d '`')
            if [[ -n "$domain" ]]; then
                echo "  🌐 URL: http://$domain"
            fi
        fi
    fi
    
    # Show direct port if available
    local port=$(docker compose port app 2>/dev/null | cut -d':' -f2 2>/dev/null || echo "")
    if [[ -n "$port" ]]; then
        echo "  🔗 Direct: http://localhost:$port"
    fi
}
#   make pip P=api CMD="install pandas"   # Run pip inside container (Python)
#
# Architecture:
#   Docker  = App containers ONLY
#   Local   = All databases (MySQL, PostgreSQL, MongoDB, Redis)
#
# ==============================================================================

# ------------------------------
# Variables
# ------------------------------
WORKSPACE?=/media/bot/INT-LOCAL1/docker-dev-workspace
P?=
TYPE?=
CONTAINER?=app
TRAEFIK_PATH?=$(WORKSPACE)/docker/traefik

# Derive compose file from project name (search across all types if TYPE not specified)
ifneq ($(P),)
  ifneq ($(TYPE),)
    # Direct path if TYPE is specified: make up P=blog TYPE=fastapi
    PROJECT_PATH=$(WORKSPACE)/projects/$(TYPE)/$(P)
    COMPOSE=docker compose -f $(PROJECT_PATH)/docker-compose.yml
  else
    # Auto-find project across all types: make up P=blog
    PROJECT_PATH=$(shell find $(WORKSPACE)/projects -name "$(P)" -type d | head -1)
    ifeq ($(PROJECT_PATH),)
      COMPOSE=@echo "ERROR: Project '$(P)' not found. Use TYPE=<type> or check project name." && exit 1 &&
    else
      COMPOSE=docker compose -f $(PROJECT_PATH)/docker-compose.yml
    endif
  endif
else
  COMPOSE=@echo "ERROR: specify project with P=<name> [TYPE=<type>]" && exit 1 &&
endif

# ------------------------------
# Phony Targets
# ------------------------------
.PHONY: up start stop down restart logs shell bash ps \
        traefik-up traefik-down traefik-logs \
        migrate migrate-fresh seed artisan composer \
        test pip npm install build dev \
        go-run go-build \
        clean clean-all list

# ==============================================================================
# Docker Compose — Generic (works with any project)
# ==============================================================================

up:
	$(COMPOSE) up -d --build

start:
	$(COMPOSE) up -d

stop:
	$(COMPOSE) stop

down:
	$(COMPOSE) down

restart: down up

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

logs-app:
	$(COMPOSE) logs -f $(CONTAINER)

# ==============================================================================
# Shell Access
# ==============================================================================

shell:
	$(COMPOSE) exec $(CONTAINER) sh

bash:
	$(COMPOSE) exec $(CONTAINER) bash

# ==============================================================================
# Traefik
# ==============================================================================

traefik-up:
	docker compose -f $(TRAEFIK_PATH)/docker-compose.yml up -d

traefik-down:
	docker compose -f $(TRAEFIK_PATH)/docker-compose.yml down

traefik-logs:
	docker compose -f $(TRAEFIK_PATH)/docker-compose.yml logs -f

# ==============================================================================
# Laravel / PHP Commands
# ==============================================================================

migrate:
	$(COMPOSE) exec $(CONTAINER) php artisan migrate

migrate-fresh:
	$(COMPOSE) exec $(CONTAINER) php artisan migrate:fresh --seed

seed:
	$(COMPOSE) exec $(CONTAINER) php artisan db:seed

artisan:
	$(COMPOSE) exec $(CONTAINER) php artisan $(CMD)

composer:
	$(COMPOSE) exec $(CONTAINER) composer $(CMD)

# ==============================================================================
# FastAPI / Python Commands
# ==============================================================================

test:
	$(COMPOSE) exec $(CONTAINER) pytest

pip:
	$(COMPOSE) exec $(CONTAINER) pip $(CMD)

python:
	$(COMPOSE) exec $(CONTAINER) python $(CMD)

# ==============================================================================
# React / Node Commands
# ==============================================================================

install:
	$(COMPOSE) exec $(CONTAINER) npm install

build:
	$(COMPOSE) exec $(CONTAINER) npm run build

dev:
	$(COMPOSE) exec $(CONTAINER) npm run dev

npm:
	$(COMPOSE) exec $(CONTAINER) npm $(CMD)

# ==============================================================================
# Golang Commands
# ==============================================================================

go-run:
	$(COMPOSE) exec $(CONTAINER) go run .

go-build:
	$(COMPOSE) exec $(CONTAINER) go build -o server .

go-test:
	$(COMPOSE) exec $(CONTAINER) go test ./...

# ==============================================================================
# Utility
# ==============================================================================

# List all projects
list:
	@echo "Projects by type:"
	@for type in $(WORKSPACE)/projects/*/; do \
		if [ -d "$$type" ]; then \
			type_name=$$(basename "$$type"); \
			echo "  $$type_name:"; \
			for project in "$$type"*/; do \
				if [ -d "$$project" ]; then \
					project_name=$$(basename "$$project"); \
					echo "    - $$project_name"; \
				fi; \
			done; \
		fi; \
	done 2>/dev/null || echo "  (no projects yet)"
	@echo ""
	@echo "Usage examples:"
	@echo "  make up P=udemmy001              # Auto-find project"
	@echo "  make up P=blog TYPE=fastapi      # Specify type"
	@echo "  make logs P=shop TYPE=laravel    # View logs"

clean:
	docker system prune -f

clean-all:
	docker system prune -af --volumes
