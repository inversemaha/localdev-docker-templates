#!/bin/bash
set -e

# PROJECT-WISE DOCKER DEV WORKSPACE TEMPLATE (Command-line argument version)
BASE_DIR="/media/bot/INT-LOCAL"
TEMPLATE_NAME="docker-dev-workspace"
TEMPLATE_DIR="$BASE_DIR/$TEMPLATE_NAME"

mkdir -p "$TEMPLATE_DIR"
cd "$TEMPLATE_DIR"

# Command-line argument for project type
PROJECT_TYPE="$1"

if [[ -z "$PROJECT_TYPE" ]]; then
  echo "Usage: $0 <project-type>"
  echo "Available project types: fastapi, laravel, react, golang"
  exit 1
fi

case "$PROJECT_TYPE" in
  fastapi)
    mkdir -p templates/fastapi
    ;;
  laravel)
    mkdir -p templates/laravel/nginx
    ;;
  react)
    mkdir -p templates/react
    ;;
  golang)
    mkdir -p templates/golang
    ;;
  *)
    echo "Unknown project type: $PROJECT_TYPE"
    echo "Available project types: fastapi, laravel, react, golang"
    exit 1
    ;;
esac

mkdir -p docker/traefik
touch README.md

echo "Project template for $PROJECT_TYPE created in $TEMPLATE_DIR."
