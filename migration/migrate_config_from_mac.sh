#!/bin/bash
#
# Migration Script: Transfer Homebridge Config from Mac to Raspberry Pi
# Run this script ON YOUR MAC to export and transfer your config to the RPi
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

# Default Homebridge storage locations on macOS
HOMEBRIDGE_STORAGE_PATHS=(
    "$HOME/.homebridge"
    "/var/lib/homebridge"
    "$HOME/Library/Application Support/homebridge"
)

# Function to find Homebridge config
find_homebridge_config() {
    local config_path=""
    
    for path in "${HOMEBRIDGE_STORAGE_PATHS[@]}"; do
        if [[ -f "$path/config.json" ]]; then
            config_path="$path"
            break
        fi
    done
    
    if [[ -z "$config_path" ]]; then
        print_error "Could not find Homebridge config.json"
        print_info "Please enter the path to your Homebridge storage directory:"
        read -r custom_path
        if [[ -f "$custom_path/config.json" ]]; then
            config_path="$custom_path"
        else
            print_error "config.json not found at $custom_path"
            exit 1
        fi
    fi
    
    echo "$config_path"
}

# Create export package
create_export_package() {
    local config_dir="$1"
    local export_dir="$HOME/homebridge-export"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local export_file="$export_dir/homebridge-config-$timestamp.tar.gz"
    
    print_status "Creating export package..."
    
    mkdir -p "$export_dir"
    
    # Create temporary directory for clean export
    local temp_export="$export_dir/temp-export"
    mkdir -p "$temp_export"
    
    # Copy essential files
    print_info "Copying config.json..."
    cp "$config_dir/config.json" "$temp_export/"
    
    # Copy accessories directory if exists
    if [[ -d "$config_dir/accessories" ]]; then
        print_info "Copying accessories..."
        cp -r "$config_dir/accessories" "$temp_export/"
    fi
    
    # Copy persist directory if exists
    if [[ -d "$config_dir/persist" ]]; then
        print_info "Copying persist data..."
        cp -r "$config_dir/persist" "$temp_export/"
    fi
    
    # Create instructions file
    cat > "$temp_export/MIGRATION_INSTRUCTIONS.txt" << 'EOF'
HOMEBRIDGE CONFIGURATION MIGRATION INSTRUCTIONS
==============================================

This package contains your Homebridge configuration exported from macOS.

TO IMPORT ON RASPBERRY PI:
--------------------------

1. Transfer this entire archive to your Raspberry Pi:
   scp homebridge-config-*.tar.gz username@raspberry-pi-ip:~

2. SSH into your Raspberry Pi:
   ssh username@raspberry-pi-ip

3. Extract the archive:
   tar -xzf homebridge-config-*.tar.gz

4. Stop Homebridge if running:
   cd ~/src/home-automation/homebridge
   ./manage_homebridge.sh stop

5. Backup existing config (if any):
   ./manage_homebridge.sh backup

6. Copy the configuration:
   sudo cp -r temp-export/* ~/src/home-automation/homebridge/config/
   sudo chown -R 1000:1000 ~/src/home-automation/homebridge/config/ 

7. Start Homebridge:
   ./manage_homebridge.sh start

8. Check logs for any issues:
   ./manage_homebridge.sh logs

9. Remove homebridge from Apple Home
   sudo hb-service uninstall
   sudo npm uninstall -g homebridge homebridge-config-ui-x
   sudo launchctl list | grep homebridge

10. Install plugins on RPi Homebridge
   Use the Homebridge UI to install the homebridge-google-nest-sdm and homebridge-ring plugins.

IMPORTANT NOTES:
---------------

- You may need to re-pair Homebridge with Apple Home
- Plugin credentials (Google, Ring) should transfer automatically
- Check that all plugins are installed in the new Homebridge instance
- Verify all devices appear in Apple Home after pairing

TROUBLESHOOTING:
---------------

If devices don't appear:
1. Check Homebridge logs for plugin errors
2. Verify plugins are installed: Homebridge UI -> Plugins
3. Ensure plugin configurations are correct: Homebridge UI -> Config
4. Try restarting Homebridge: ./manage_homebridge.sh restart

If pairing fails:
1. Reset Homebridge: Homebridge UI -> Settings -> Unpair Bridge
2. Remove bridge from Apple Home
3. Restart Homebridge
4. Re-scan QR code in Apple Home
EOF
    
    # Create the archive
    print_status "Creating compressed archive..."
    tar -czf "$export_file" -C "$export_dir" temp-export
    
    # Cleanup
    rm -rf "$temp_export"
    
    echo "$export_file"
}

# Generate migration guide
generate_migration_guide() {
    local export_file="$1"
    local rpi_ip="$2"
    local rpi_user="$3"
    
    print_status "╔════════════════════════════════════════════╗"
    print_status "║   Configuration Exported Successfully!    ║"
    print_status "╚════════════════════════════════════════════╝"
    echo ""
    print_info "Export package created at:"
    echo "  $export_file"
    echo ""
    print_status "NEXT STEPS:"
    echo ""
    echo "1. Transfer the configuration to your Raspberry Pi:"
    echo "   ${BLUE}scp \"$export_file\" $rpi_user@$rpi_ip:~${NC}"
    echo ""
    echo "2. SSH into your Raspberry Pi:"
    echo "   ${BLUE}ssh $rpi_user@$rpi_ip${NC}"
    echo ""
    echo "3. On the Raspberry Pi, run:"
    echo "   ${BLUE}tar -xzf $(basename "$export_file")${NC}"
    echo "   ${BLUE}cat temp-export/MIGRATION_INSTRUCTIONS.txt${NC}"
    echo ""
    echo "4. Follow the instructions in MIGRATION_INSTRUCTIONS.txt"
    echo ""
    echo "5. Access Homebridge UI at: ${BLUE}http://$rpi_ip:8581${NC}"
    echo ""
    print_warning "Remember to stop Homebridge on your Mac after successful migration!"
    echo ""
}

# Export credentials guide
create_credentials_checklist() {
    local export_dir="$HOME/homebridge-export"
    local checklist_file="$export_dir/CREDENTIALS_CHECKLIST.txt"
    
    # Ensure export directory exists
    mkdir -p "$export_dir"
    
    cat > "$checklist_file" << 'EOF'
HOMEBRIDGE CREDENTIALS CHECKLIST
================================

Before migrating, ensure you have these credentials saved:

GOOGLE NEST (homebridge-google-nest-sdm):
□ OAuth Client ID
□ OAuth Client Secret
□ SDM Project ID
□ Refresh Token
□ PubSub Subscription Name
□ GCP Project ID

RING (homebridge-ring):
□ Ring account username/email
□ Ring account password
□ Two-factor authentication access

HOMEBRIDGE:
□ Homebridge UI username (default: admin)
□ Homebridge UI password (default: admin - CHANGE THIS!)

APPLE HOME:
□ You will need to re-pair Homebridge with Apple Home
□ The pairing code will be shown in the Homebridge UI on the RPi

NETWORK:
□ Raspberry Pi static IP address (recommended)
□ Router/network configuration if port forwarding is needed

BACKUP LOCATIONS (just in case):
□ Google credentials stored in config.json
□ Ring credentials stored in config.json
□ Full config.json backed up separately

NOTES:
------
Most plugin credentials are stored in config.json and will transfer
automatically. However, it's good to have them documented separately.

After migration, verify in the Homebridge UI that all plugins show
as "connected" and not in an error state.
EOF
    
    print_info "Credentials checklist created at: $checklist_file"
    cat "$checklist_file"
    echo ""
}

# Main function
main() {
    echo ""
    echo "╔════════════════════════════════════════════╗"
    echo "║  Homebridge Mac to Raspberry Pi Migration ║"
    echo "╚════════════════════════════════════════════╝"
    echo ""
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "This script is designed to run on macOS"
        print_info "Continue anyway? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Find Homebridge config
    print_status "Searching for Homebridge configuration..."
    CONFIG_DIR=$(find_homebridge_config)
    print_status "Found Homebridge config at: $CONFIG_DIR"
    echo ""
    
    # Create credentials checklist
    create_credentials_checklist
    
    # Get Raspberry Pi details
    print_status "Enter your Raspberry Pi details:"
    read -p "Raspberry Pi IP address: " RPI_IP
    read -p "Raspberry Pi username: " RPI_USER
    echo ""
    
    # Confirm
    print_warning "This will export your Homebridge configuration."
    print_info "Continue? (y/n)"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Migration cancelled"
        exit 0
    fi
    
    # Create export package
    EXPORT_FILE=$(create_export_package "$CONFIG_DIR")
    
    # Generate migration guide
    generate_migration_guide "$EXPORT_FILE" "$RPI_IP" "$RPI_USER"
    
    # Offer to transfer automatically
    echo ""
    print_info "Would you like to transfer the file now? (y/n)"
    read -r transfer
    if [[ "$transfer" =~ ^[Yy]$ ]]; then
        print_status "Transferring file to Raspberry Pi..."
        if scp "$EXPORT_FILE" "$RPI_USER@$RPI_IP:~"; then
            print_status "Transfer complete!"
            echo ""
            print_info "Now SSH into your Raspberry Pi and extract the archive:"
            echo "  ${BLUE}ssh $RPI_USER@$RPI_IP${NC}"
            echo "  ${BLUE}tar -xzf $(basename "$EXPORT_FILE")${NC}"
        else
            print_error "Transfer failed. Please copy manually."
        fi
    fi
    
    echo ""
    print_status "Migration export complete!"
}

# Run main
main