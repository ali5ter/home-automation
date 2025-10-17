#!/usr/bin/env bash
# @file: start_stack.sh
# @brief: Initialize and start the automation stack via Docker Compose
# @author: Alister Lewis-Bowen <alister@lewis-bowen.org>

check_docker_access() {
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
}

stand_up_homebridge() {
  echo "➡️  Setting up Homebridge..."
  cd homebridge || { echo "❌ Failed to change directory to 'homebridge'."; exit 1; }

  set -a
  # shellcheck disable=SC1091
  source .env
  set +a

  docker compose up -d

  echo "✅ Homebridge setup complete!"
  echo "🌐 HomeBridge: http://${HB_SERVER_IP}:${HB_SERVER_PORT}"
}

echo "🔍 Checking Docker access..."
check_docker_access

echo "🚀 Starting automation stack using Docker Compose..."
stand_up_homebridge