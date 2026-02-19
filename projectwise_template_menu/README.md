# Projectwise Template (Interactive Menu Version)

This template allows you to generate a Docker development workspace for a specific project type using an interactive menu.

## Usage

Run the script and select the project type from the menu:

```bash
./setup_projectwise_template.sh
```

Available project types:
- fastapi
- laravel
- react
- golang

Only the selected template will be generated.

## How to Select and Generate Individual Project Templates

1. Navigate to this folder:
   ```bash
   cd projectwise_template_menu
   ```
2. Run the script:
   ```bash
   ./setup_projectwise_template.sh
   ```
3. Select your desired project type (e.g., fastapi, laravel) from the menu.
   Only the selected template will be generated.

## Structure
- templates/<project-type>/
- docker/traefik/
- README.md

## Example
Run the script and follow the prompt to select your project type.
