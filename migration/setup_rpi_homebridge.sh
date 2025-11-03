#!/bin/bash
# 
# Raspberry Pi 4B Homebridge Server Setup Script
# This script automates the initial setup of your RPi for Homebridge
#

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

# Check if running on Raspberry Pi
check_raspberry_pi() {
    if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model; then
        print_warning "This doesn't appear to be a Raspberry Pi. Continue anyway? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_status "Detected: $(cat /proc/device-tree/model)"
    fi
}

# Update system
update_system() {
    print_status "Updating system packages..."
    sudo apt update
    sudo apt full-upgrade -y
    print_status "System updated successfully"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        print_status "Docker is already installed ($(docker --version))"
        return
    fi

    print_status "Installing Docker..."
    
    # Remove any conflicting packages first
    print_info "Removing any conflicting Docker packages..."
    sudo apt remove -y docker-buildx docker-compose docker-cli 2>/dev/null || true
    
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh

    print_status "Adding $USER to docker group..."
    sudo usermod -aG docker "$USER"
    
    print_warning "You'll need to log out and back in for docker group changes to take effect"
}

# Install Docker Compose
install_docker_compose() {
    # Check if docker compose plugin is available (installed by Docker script)
    if docker compose version &> /dev/null; then
        print_status "Docker Compose plugin is already installed ($(docker compose version))"
        print_info "You can use 'docker compose' (no hyphen) commands"
        
        # Create a symlink for docker-compose compatibility
        if [[ ! -f /usr/local/bin/docker-compose ]]; then
            print_status "Creating docker-compose symlink for compatibility..."
            sudo tee /usr/local/bin/docker-compose > /dev/null << 'DCEOF'
#!/bin/bash
docker compose "$@"
DCEOF
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        return
    fi
    
    # If plugin not available, try standalone docker-compose
    if command -v docker-compose &> /dev/null; then
        print_status "Docker Compose is already installed ($(docker-compose --version))"
        return
    fi

    print_status "Installing Docker Compose standalone..."
    # Download latest docker-compose binary
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_status "Docker Compose installed successfully"
}

# Install Avahi for mDNS
install_avahi() {
    if systemctl is-active --quiet avahi-daemon; then
        print_status "Avahi daemon is already running"
        return
    fi

    print_status "Installing and starting Avahi (mDNS/Bonjour)..."
    sudo apt install -y avahi-daemon avahi-utils
    sudo systemctl enable avahi-daemon
    sudo systemctl start avahi-daemon
    print_status "Avahi installed and running"
}

# Install useful utilities
install_utilities() {
    print_status "Installing useful utilities..."
    sudo apt install -y \
        git \
        curl \
        vim \
        htop \
        net-tools \
        dnsutils
    print_status "Utilities installed"
}

# Create docker-compose.yml for Homebridge
create_docker_compose() {
    local compose_dir="$REPO_DIR/homebridge"
    
    print_status "Creating Homebridge docker-compose.yml..."
    
    mkdir -p "$compose_dir"
    
    cat > "$compose_dir/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  homebridge:
    image: homebridge/homebridge:latest
    container_name: homebridge
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./config:/homebridge
    environment:
      - TZ=America/New_York
      - HOMEBRIDGE_CONFIG_UI=1
      - HOMEBRIDGE_CONFIG_UI_PORT=8581
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  # Optional: Watchtower for automatic updates
  # Uncomment to enable automatic container updates
  # watchtower:
  #   image: containrrr/watchtower
  #   container_name: watchtower
  #   restart: unless-stopped
  #   volumes:
  #     - /var/run/docker.sock:/var/run/docker.sock
  #   environment:
  #     - WATCHTOWER_CLEANUP=true
  #     - WATCHTOWER_SCHEDULE=0 0 4 * * *  # 4 AM daily
  #     - WATCHTOWER_INCLUDE_STOPPED=false
  #     - WATCHTOWER_REVIVE_STOPPED=false
EOF

    print_status "docker-compose.yml created at $compose_dir/docker-compose.yml"
}

# Create backup script
create_backup_script() {
    local backup_script="$HOME/backup-homebridge.sh"
    
    print_status "Creating backup script..."
    
    cat > "$backup_script" << 'EOF'
#!/bin/bash
# Homebridge Configuration Backup Script

BACKUP_DIR="$HOME/homebridge-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOMEBRIDGE_CONFIG="$HOME/home-automation/homebridge/config"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Check if config directory exists
if [[ ! -d "$HOMEBRIDGE_CONFIG" ]]; then
    echo "ERROR: Homebridge config directory not found at $HOMEBRIDGE_CONFIG"
    exit 1
fi

# Create backup
echo "Creating backup..."
tar -czf "$BACKUP_DIR/homebridge-config-$TIMESTAMP.tar.gz" \
    -C "$(dirname "$HOMEBRIDGE_CONFIG")" "$(basename "$HOMEBRIDGE_CONFIG")"

if [[ $? -eq 0 ]]; then
    echo "Backup created successfully: homebridge-config-$TIMESTAMP.tar.gz"
    
    # Keep only last 7 backups
    ls -t "$BACKUP_DIR"/homebridge-config-*.tar.gz | tail -n +8 | xargs -r rm
    echo "Old backups cleaned up (keeping last 7)"
else
    echo "ERROR: Backup failed"
    exit 1
fi
EOF

    chmod +x "$backup_script"
    print_status "Backup script created at $backup_script"
}

# Create management script
create_management_script() {
    local mgmt_script="$REPO_DIR/manage_homebridge.sh"
    
    print_status "Creating management script..."
    
    cat > "$mgmt_script" << 'EOF'
#!/bin/bash
# Homebridge Management Script

HOMEBRIDGE_DIR="$HOME/home-automation/homebridge"

cd "$HOMEBRIDGE_DIR" || exit 1

case "$1" in
    start)
        echo "Starting Homebridge..."
        docker-compose up -d
        RPI_IP=$(hostname -I | awk '{print $1}')
        echo "Homebridge started. Access UI at http://$RPI_IP:8581"
        ;;
    stop)
        echo "Stopping Homebridge..."
        docker-compose down
        ;;
    restart)
        echo "Restarting Homebridge..."
        docker-compose restart
        ;;
    logs)
        echo "Showing Homebridge logs (Ctrl+C to exit)..."
        docker-compose logs -f homebridge
        ;;
    status)
        echo "Homebridge container status:"
        docker-compose ps
        ;;
    update)
        echo "Updating Homebridge..."
        docker-compose pull
        docker-compose up -d
        echo "Homebridge updated"
        ;;
    backup)
        if [[ -f "$HOME/backup-homebridge.sh" ]]; then
            "$HOME/backup-homebridge.sh"
        else
            echo "ERROR: Backup script not found"
            exit 1
        fi
        ;;
    shell)
        echo "Opening shell in Homebridge container..."
        docker exec -it homebridge sh
        ;;
    *)
        echo "Homebridge Management Script"
        echo ""
        echo "Usage: $0 {start|stop|restart|logs|status|update|backup|shell}"
        echo ""
        echo "Commands:"
        echo "  start   - Start Homebridge"
        echo "  stop    - Stop Homebridge"
        echo "  restart - Restart Homebridge"
        echo "  logs    - View Homebridge logs"
        echo "  status  - Check container status"
        echo "  update  - Update to latest Homebridge version"
        echo "  backup  - Backup configuration"
        echo "  shell   - Access container shell"
        exit 1
        ;;
esac
EOF

    chmod +x "$mgmt_script"
    print_status "Management script created at $mgmt_script"
}

# Setup systemd service for auto-start
create_systemd_service() {
    print_status "Creating systemd service for automatic startup..."
    
    local service_file="/etc/systemd/system/homebridge.service"
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Homebridge Docker Container
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$REPO_DIR/homebridge
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
User=$USER
Group=$USER

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable homebridge.service
    
    print_status "Systemd service created and enabled"
    print_warning "Homebridge will now start automatically on boot"
}

# Configure static IP helper
configure_static_ip_helper() {
    print_status "Static IP Configuration Helper"
    echo ""
    echo "It's highly recommended to set a static IP for your Homebridge server."
    CURRENT_IP=$(hostname -I | awk '{print $1}')
    echo "Current IP: $CURRENT_IP"
    echo ""
    echo "Would you like help configuring a static IP? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_status "To configure a static IP, edit /etc/dhcpcd.conf"
        print_status "Add these lines (example using $CURRENT_IP):"
        echo ""
        echo "interface eth0"
        echo "static ip_address=$CURRENT_IP/24"
        echo "static routers=192.168.1.1"
        echo "static domain_name_servers=192.168.1.1 8.8.8.8"
        echo ""
        print_warning "Adjust the IP address and router IP to match your network!"
        print_warning "After editing, reboot your Pi for changes to take effect"
        echo ""
        echo "Open the file now? (y/n)"
        read -r edit_response
        if [[ "$edit_response" =~ ^[Yy]$ ]]; then
            sudo nano /etc/dhcpcd.conf
        fi
    fi
}

# Main setup function
main() {
    echo ""
    echo "╔════════════════════════════════════════════╗"
    echo "║   Raspberry Pi Homebridge Setup Script    ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""
    
    check_raspberry_pi
    update_system
    install_utilities
    install_docker
    install_docker_compose
    install_avahi
    create_docker_compose
    create_backup_script
    create_management_script
    create_systemd_service
    configure_static_ip_helper
    
    echo ""
    print_status "╔════════════════════════════════════════════╗"
    print_status "║         Setup Complete!                    ║"
    print_status "╚════════════════════════════════════════════╝"
    echo ""
    print_warning "IMPORTANT: Log out and back in for Docker group changes to take effect!"
    echo ""
    local rpi_ip=$(hostname -I | awk '{print $1}')
    print_status "Next steps:"
    echo "  1. Log out: exit"
    echo "  2. SSH back in to: ssh $USER@$rpi_ip"
    echo "  3. Start Homebridge: cd ~/home-automation && ./manage_homebridge.sh start"
    echo "  4. Access UI at: http://$rpi_ip:8581"
    echo "  5. Default login: admin/admin (change immediately!)"
    echo ""
    print_status "Use './manage_homebridge.sh' for easy management"
    echo ""
}

# Run main function
main