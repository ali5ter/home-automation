#!/usr/bin/env bash
# @file: start_stack.sh
# @brief: Initialize and start the automation stack via Docker Compose
# @author: Alister Lewis-Bowen <alister@lewis-bowen.org>

set -a
# shellcheck disable=SC1091
source .env
set +a

echo "🔍 Checking Docker access..."

if ! docker info &> /dev/null; then
  if [[ "$(uname)" == "Linux" ]]; then
    echo "⚠️  Docker is installed, but your user doesn't have permission to access the Docker daemon."

    if groups "$USER" | grep -q '\bdocker\b'; then
      echo "❌ You're already in the 'docker' group, but it looks like your session hasn't picked it up yet."
      echo "🔄 Please log out and log back in (or reboot) to apply group changes."
      exit 1
    else
      echo "➕ Adding user '$USER' to the 'docker' group..."
      sudo usermod -aG docker "$USER"
      echo "✅ User added to the 'docker' group."
      echo "🔄 Please log out and log back in (or reboot) before re-running this script."
      exit 1
    fi
  else
    echo "❌ Docker is not accessible, and you're not on a supported Linux system."
    echo "ℹ️ On macOS or Docker Desktop, make sure Docker is running."
    exit 1
  fi
else
  echo "✅ Docker is accessible."
fi

echo "🚀 Starting automation stack using Docker Compose..."

SERVER_IP=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')

cd homebridge || { echo "❌ Failed to change directory to 'homebridge'."; exit 1; }
docker compose up -d

echo
echo "✅ Setup complete!"
echo "🌐 HomeBridge: http://${SERVER_IP}:8581"