#!/bin/bash
set -e

echo "🚀 Setting up Clean Engineering Local Environment..."

# Update
sudo apt update && sudo apt upgrade -y

# Install essentials
sudo apt install -y \
  ca-certificates curl gnupg lsb-release git

# ------------------------------
# Docker Install (FIXED for Linux Mint)
# ------------------------------
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# FIXED: Use 'noble' instead of $(lsb_release -cs)
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

# ------------------------------
# NVM (Optional)
# ------------------------------
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

echo ""
echo "✅ Setup Complete!"
echo "👉 Logout & Login before using Docker"
