# Raspberry Pi 4B Homebridge Server Setup

These are notes about setting up a dedicated Homebridge server on a Raspberry Pi 4B.

## Why Raspberry Pi instead of macOS?

Docker on macOS has significant networking limitations:

- Docker Desktop for macOS doesn't expose container mDNS/Bonjour to your LAN
- Apple Home cannot reliably discover Homebridge running in Docker on Mac
- Host networking mode doesn't work on Mac (it's virtualized)
- When your Mac sleeps, your smart home goes offline

Running Homebridge on a Raspberry Pi solves all these issues with a dedicated, always-on server.

## Prerequisites

- Raspberry Pi 4B (2GB+ RAM recommended)
- MicroSD card (32GB+ recommended)
- Power supply for RPi 4B
- Ethernet cable (recommended for stability) or WiFi
- Static IP address for your RPi on your home network

## Initial Raspberry Pi Setup

### 1. Install Raspberry Pi OS

1. Download and install [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Flash **Raspberry Pi OS Lite (64-bit)** to your microSD card
3. Before ejecting, configure:
   - Hostname: `homebridge-server` (or your preference)
   - Enable SSH with password authentication
   - Set username and password
   - Configure WiFi if not using Ethernet
   - Set your timezone

### 2. Boot and Connect

1. Insert the microSD card into your RPi and power it on
2. Wait 1-2 minutes for boot
3. Find your Pi's IP address from your router's connected devices list or DHCP clients page
4. SSH into your Pi: `ssh username@<ip-address>` (e.g., `ssh pi@192.168.1.33`)

### 3. Initial System Configuration

```bash
# Update system
sudo apt update && sudo apt full-upgrade -y

# Install essential packages
sudo apt install -y git curl vim

# Set a static IP (recommended)
# Edit /etc/dhcpcd.conf and add:
sudo nano /etc/dhcpcd.conf
```

Add these lines at the end (adjust for your network):
```
interface eth0
static ip_address=192.168.1.33/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
```

Reboot: `sudo reboot`

## Installing Docker and Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to docker group (no sudo needed)
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
exit
# SSH back in

# Install Docker Compose
sudo apt install -y docker-compose

# Verify installation
docker --version
docker-compose --version
```

## Clone Your Repository

```bash
cd ~
git clone https://github.com/ali5ter/home-automation.git
cd home-automation
```

## Homebridge Docker Setup for Raspberry Pi

The key difference on Raspberry Pi is that we need to use **host networking mode** for proper mDNS/Bonjour discovery.

Create or update `homebridge/docker-compose.yml` with the following configuration:

```yaml
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
      - TZ=America/New_York  # Set your timezone
      - HOMEBRIDGE_CONFIG_UI=1
      - HOMEBRIDGE_CONFIG_UI_PORT=8581
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

## Starting Homebridge

```bash
# Navigate to homebridge directory
cd ~/home-automation/homebridge

# Start Homebridge
docker-compose up -d

# Check logs
docker-compose logs -f homebridge

# You should see logs indicating Homebridge is starting
# Look for messages about the Config UI being available
```

## Accessing Homebridge UI

1. Open your browser to: `http://<raspberry-pi-ip>:8581` (e.g., `http://192.168.1.33:8581`)
2. Default login:
   - Username: `admin`
   - Password: `admin` (change this immediately!)

## Pairing with Apple Home

1. In the Homebridge UI, go to the **Status** page
2. You'll see a QR code and pairing code in the top-left
3. On your iPhone:
   - Open **Home** app
   - Tap **+** → **Add Accessory**
   - Tap **More options...**
   - Homebridge should appear automatically (thanks to host networking!)
   - If not, tap **Enter Code Manually** and use the code from Homebridge UI
4. Follow the pairing prompts
5. After a few seconds, the Status page should show "Paired"

## Installing Nest Thermostat Plugin

Follow the same Google SDM setup process from your existing documentation, then:

1. In Homebridge UI, go to **Plugins**
2. Search for `homebridge-google-nest-sdm`
3. Click **Install**
4. After installation, click **Settings**
5. Enter your Google credentials:
   - OAuth Client ID and Secret
   - SDM Project ID
   - Refresh Token
   - PubSub Subscription Name
   - GCP Project ID
6. Save and restart Homebridge

## Installing Ring Doorbell Plugin

First, install ffmpeg in the Docker container:

```bash
# Access the container
docker exec -it homebridge sh

# Install ffmpeg
apk add ffmpeg

# Exit container
exit
```

Alternatively, add this to a custom Dockerfile if you want it permanent.

Then in Homebridge UI:

1. Go to **Plugins**
2. Search for `homebridge-ring`
3. Click **Install**
4. Configure with your Ring credentials
5. Enable 2FA when prompted
6. Recommended settings:
   - Hide In-Home Doorbell Switch: ✓
   - Hide Doorbell Programmable Switch: ✓
   - Debug Logging: ✓
   - Camera/Chime Status Polling: 20 seconds
   - Avoid Snapshot Battery Drain: ✓
7. Save and restart

## Backup Your Configuration

```bash
# Create a backup script
cat > ~/backup-homebridge.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="$HOME/homebridge-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP_DIR"

# Backup homebridge config
tar -czf "$BACKUP_DIR/homebridge-config-$TIMESTAMP.tar.gz" \
    -C "$HOME/home-automation/homebridge" config

# Keep only last 7 backups
ls -t "$BACKUP_DIR"/homebridge-config-*.tar.gz | tail -n +8 | xargs -r rm

echo "Backup completed: homebridge-config-$TIMESTAMP.tar.gz"
EOF

chmod +x ~/backup-homebridge.sh

# Run backup manually
~/backup-homebridge.sh

# Or set up a daily cron job
(crontab -l 2>/dev/null; echo "0 2 * * * $HOME/backup-homebridge.sh") | crontab -
```

## Maintenance Commands

```bash
# View logs
cd ~/home-automation/homebridge
docker-compose logs -f homebridge

# Restart Homebridge
docker-compose restart

# Stop Homebridge
docker-compose down

# Update Homebridge to latest version
docker-compose pull
docker-compose up -d

# Check container status
docker ps

# Access container shell
docker exec -it homebridge sh
```

## Troubleshooting

### Homebridge not appearing in Home app

1. Verify host networking is working:
   ```bash
   docker ps
   # Should show network mode as "host"
   ```

2. Check if Avahi/mDNS is working on the Pi:
   ```bash
   sudo apt install avahi-daemon
   sudo systemctl status avahi-daemon
   ```

3. Check firewall (if enabled):
   ```bash
   sudo ufw allow 8581/tcp
   sudo ufw allow 5353/udp  # mDNS
   ```

### Plugin not working

1. Check Homebridge logs for errors
2. Verify plugin configuration in the JSON config
3. Try removing and reinstalling the plugin
4. Check plugin-specific documentation

### Container won't start

1. Check logs: `docker-compose logs homebridge`
2. Verify docker-compose.yml syntax
3. Ensure volumes/directories exist
4. Check disk space: `df -h`

## Performance Tips

- Use Ethernet instead of WiFi for more reliable connectivity
- Ensure adequate cooling for your RPi 4B (case with fan recommended)
- Monitor temperature: `vcgencmd measure_temp`
- Consider overclocking only if needed and with adequate cooling
- Use a quality power supply (official RPi 4 power supply recommended)

## Automatic Updates (Optional)

To keep your Homebridge Docker image updated automatically:

```bash
# Install Watchtower
cd ~/home-automation/homebridge
nano docker-compose.yml
```

Add Watchtower service:

```yaml
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *  # 4 AM daily
```

## Next Steps

1. Export your Homebridge configuration from your Mac setup
2. Import it to your RPi Homebridge instance via the JSON Config page
3. Verify all devices appear in Apple Home
4. Test automations
5. Shut down Homebridge on your Mac
6. Enjoy 24/7 smart home automation!
