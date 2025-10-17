#!/usr/bin/env bash
# @file: update_native_homebridge.sh
# @brief: Uninstall and update a native Homebridge installation on macOS
# @note: Node v22 is required for Homebridge compatibility
# @note: Homebridge config is stored at /Users/<username>/.homebridge
# @note: This script is intended for macOS systems
# @author: Alister Lewis-Bowen <alister@lewis-bowen.org>

set -a
# shellcheck disable=SC1091
source .env
set +a

echo "Homebridge version: $(homebridge -V)
npm version: $(npm -v)
Node version: $(node -v)"

# At time of writing, the latest Node version is 24. Homebridge requires
# Node 22 LTS.
brew install node@22
brew unlink node
brew link --overwrite --force node@22
echo "npm version: $(npm -v)"

echo
echo "🔄 Updating native Homebridge installation..."
sudo hb-service stop
sudo hb-service uninstall

# Remove existing launchd service since this seems to be an issue with updating
# Homebridge on macOS
sudo launchctl bootout system /Library/LaunchDaemons/com.homebridge.server.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.homebridge.server.plist

sudo npm -g uninstall homebridge homebridge-config-ui-x
sudo npm -g install --unsafe-perm homebridge@latest homebridge-config-ui-x@latest
sudo hb-service install
echo "Homebridge version: $(homebridge -V)"

echo
echo "🚀 Starting native Homebridge service..."
sudo hb-service start
sleep 5
sudo hb-service status

echo
echo "✅ Setup complete!"
echo "🌐 HomeBridge: http://${HB_SERVER_IP}:${HB_SERVER_PORT}"