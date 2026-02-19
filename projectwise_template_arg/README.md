# Projectwise Template (Command-line Argument Version)

This template allows you to generate a Docker development workspace for a specific project type using a command-line argument.

## Usage

Run the script with the desired project type:

```bash
./setup_projectwise_template.sh <project-type>
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
   cd projectwise_template_arg
   ```
2. Run the script with your desired project type:
   ```bash
   ./setup_projectwise_template.sh fastapi
   ./setup_projectwise_template.sh laravel
   ./setup_projectwise_template.sh react
   ./setup_projectwise_template.sh golang
   ```
   Only the specified template will be generated.

## Structure
- templates/<project-type>/
- docker/traefik/
- README.md

## Example
```bash
./setup_projectwise_template.sh fastapi
```
