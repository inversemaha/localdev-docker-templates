# ==============================================================================
# Makefile — Docker Dev Workspace Manager
# ==============================================================================
#
# Usage:
#   make up P=my-blog                     # Build & start a project
#   make logs P=my-blog                   # Follow logs
#   make shell P=my-blog                  # Shell into app container
#   make artisan P=my-blog CMD=migrate    # Run artisan command
#   make pip P=ml-api CMD="install pandas" # Run pip inside container
#
# Architecture:
#   Docker  = App containers ONLY
#   Local   = All databases (MySQL, PostgreSQL, MongoDB, Redis)
#
# ==============================================================================

# ------------------------------
# Variables
# ------------------------------
WORKSPACE?=/media/bot/INT-LOCAL/docker-dev-workspace
P?=
CONTAINER?=app
TRAEFIK_PATH?=$(WORKSPACE)/docker/traefik

# Derive compose file from project name
ifneq ($(P),)
  PROJECT_PATH=$(WORKSPACE)/projects/$(P)
  COMPOSE=docker compose -f $(PROJECT_PATH)/docker-compose.yml
else
  COMPOSE=@echo "ERROR: specify project with P=<name>" && exit 1 &&
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
	@echo "Projects:"
	@ls -1 $(WORKSPACE)/projects 2>/dev/null || echo "  (none yet)"
	@echo ""
	@echo "Templates:"
	@ls -1 $(WORKSPACE)/templates

clean:
	docker system prune -f

clean-all:
	docker system prune -af --volumes
