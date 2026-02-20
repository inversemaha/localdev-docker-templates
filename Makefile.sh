# ==============================================================================
# Makefile — Docker Dev Workspace Manager
# ==============================================================================
#
# Usage:
#   make up P=my-blog                     # Auto-find & start project
#   make up P=my-blog TYPE=laravel        # Start specific type project
#   make logs P=shop TYPE=fastapi         # Follow logs
#   make shell P=dashboard TYPE=react     # Shell into app container
#   make artisan P=shop CMD=migrate       # Run artisan command (Laravel)
#   make pip P=ml-api CMD="install pandas" # Run pip inside container (Python)
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
	@echo "  make up P=blog              # Auto-find project"
	@echo "  make up P=blog TYPE=fastapi # Specify type"
	@echo "  make logs P=shop TYPE=laravel    # View logs"

clean:
	docker system prune -f

clean-all:
	docker system prune -af --volumes
