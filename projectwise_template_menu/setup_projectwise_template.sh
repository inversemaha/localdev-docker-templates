#!/bin/bash
set -e

# PROJECT-WISE DOCKER DEV WORKSPACE TEMPLATE (Interactive menu version)
BASE_DIR="/media/bot/INT-LOCAL"
TEMPLATE_NAME="docker-dev-workspace"
TEMPLATE_DIR="$BASE_DIR/$TEMPLATE_NAME"

mkdir -p "$TEMPLATE_DIR"
cd "$TEMPLATE_DIR"

# Interactive menu for project type
PS3="Select the project type: "
options=("fastapi" "laravel" "react" "golang" "quit")
select opt in "${options[@]}"; do
  case $opt in
    fastapi)
      mkdir -p templates/fastapi
      PROJECT_TYPE="fastapi"
      break
      ;;
    laravel)
      mkdir -p templates/laravel/nginx
      PROJECT_TYPE="laravel"
      break
      ;;
    react)
      mkdir -p templates/react
      PROJECT_TYPE="react"
      break
      ;;
    golang)
      mkdir -p templates/golang
      PROJECT_TYPE="golang"
      break
      ;;
    quit)
      echo "Exiting."
      exit 0
      ;;
    *)
      echo "Invalid option. Please select a valid project type."
      ;;
  esac
done

mkdir -p docker/traefik
touch README.md

echo "Project template for $PROJECT_TYPE created in $TEMPLATE_DIR."
