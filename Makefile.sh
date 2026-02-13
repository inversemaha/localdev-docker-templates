# Dynamic Makefile for any project
# Usage:
#   make up PROJECT_PATH=projects/laravel
#   make logs PROJECT_PATH=projects/fastapi
#   make shell PROJECT_PATH=projects/react CONTAINER=react_app

# ------------------------------
# Variables
# ------------------------------
PROJECT_PATH?=.
CONTAINER?=app
TRAEFIK_PATH?=docker/traefik

# Auto-detect container names based on PROJECT_PATH
ifeq ($(PROJECT_PATH),projects/laravel)
	CONTAINER=laravel_app
else ifeq ($(PROJECT_PATH),projects/fastapi)
	CONTAINER=fastapi_app
else ifeq ($(PROJECT_PATH),projects/react)
	CONTAINER=react_app
endif

# ------------------------------
# Phony Targets
# ------------------------------
.PHONY: up start stop down restart logs shell bash ps clean traefik-up traefik-down migrate seed test install build

# ------------------------------
# Docker Compose Commands
# ------------------------------

up:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml up -d --build

start:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml up -d

stop:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml stop

down:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml down

down-volumes:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml down -v

restart: down up

ps:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml ps

logs:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml logs -f

logs-container:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml logs -f $(CONTAINER)

# ------------------------------
# Shell Access
# ------------------------------

shell:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) sh

bash:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) bash

# ------------------------------
# Traefik Commands
# ------------------------------

traefik-up:
	docker compose -f $(TRAEFIK_PATH)/docker-compose.yml up -d

traefik-down:
	docker compose -f $(TRAEFIK_PATH)/docker-compose.yml down

traefik-logs:
	docker compose -f $(TRAEFIK_PATH)/docker-compose.yml logs -f

# ------------------------------
# Project-Specific Commands
# ------------------------------

# Laravel
migrate:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) php artisan migrate

migrate-fresh:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) php artisan migrate:fresh --seed

seed:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) php artisan db:seed

artisan:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) php artisan $(CMD)

composer:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) composer $(CMD)

# FastAPI / Python
test:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) pytest

pip:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) pip $(CMD)

# React / Node
install:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) npm install

build:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) npm run build

dev:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) npm run dev

npm:
	docker compose -f $(PROJECT_PATH)/docker-compose.yml exec $(CONTAINER) npm $(CMD)

# ------------------------------
# Utility
# ------------------------------

clean:
	docker system prune -f

clean-all:
	docker system prune -af --volumes
