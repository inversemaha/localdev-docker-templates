#!/bin/bash
set -e

echo "============================================================"
echo "  Local Machine Setup — Linux Mint"
echo "============================================================"
echo ""
echo "  This script installs:"
echo "    - System essentials (git, curl, etc.)"
echo "    - Docker + Docker Compose"
echo "    - NVM (Node Version Manager)"
echo ""
echo "  Databases (MySQL, PostgreSQL, MongoDB, Redis) are"
echo "  already installed locally — this script skips them."
echo "  Docker is used ONLY for app containers."
echo "============================================================"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# ==============================================================================
# SYSTEM UPDATE & ESSENTIALS
# ==============================================================================
echo "\n>>> Updating system..."
sudo apt update && sudo apt upgrade -y

sudo apt install -y \
  ca-certificates curl gnupg lsb-release git wget \
  build-essential software-properties-common apt-transport-https

# ==============================================================================
# DOCKER (Fixed for Linux Mint — uses Ubuntu 'noble' codename)
# ==============================================================================
echo "\n>>> Installing Docker..."
sudo mkdir -p /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  noble stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER

# Create traefik network if it doesn't exist
docker network create traefik_net 2>/dev/null || true

# ==============================================================================
# NVM (Node Version Manager)
# ==============================================================================
echo "\n>>> Installing NVM..."
if [ ! -d "$HOME/.nvm" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
  echo "NVM already installed, skipping."
fi

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "============================================================"
echo "  Setup Complete!"
echo "============================================================"
echo ""
echo "  Installed:"
echo "    Docker:  $(docker --version 2>/dev/null || echo 'NOT FOUND')"
echo "    NVM:     ~/.nvm"
echo ""
echo "  Traefik network: traefik_net (created)"
echo ""
echo "  >>> Logout & Login to use Docker without sudo <<<"
echo "============================================================"
