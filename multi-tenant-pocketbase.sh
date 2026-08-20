#!/bin/bash

# This file is not related to flutter or dart.
# However, I don't know where else to put it.

# This script automates the setup of a PocketBase instance on a Linux server,
# creating a directory, configuring a systemd service, and integrating with Caddy as a reverse proxy.
# It prompts for a hostname, email, and password to create an admin account
# and ensures the instance runs on an available port.
# Ideal for quickly deploying and managing multiple PocketBase backends.

# Requirements:
# - pocketbase_0.23.6_linux_amd64.zip file must be in /opt/
# - Caddy must be installed and configured
# - The script assumes the presence of a Caddyfile in /etc/caddy/Caddyfile
# - The script assumes the presence of a systemd services units in /lib/systemd/system/

# All of the above requirements can be met by simply using digitalocean's pocketbase droplet
# Then you simply just place the pocketbase_0.23.6_linux_amd64.zip file in /opt/
# and run the script for each instance you want to create

# If you want to use a different version of pocketbase
# simply replace the pocketbase_0.23.6_linux_amd64.zip file in /opt/
# and rename the zip_filename variable to the new version file

# Exit on any error
set -e

# Prompt the user for input
read -p "Enter hostname: " hostname
read -p "Enter email: " email
read -sp "Enter password: " password
echo

# Define paths and variables
zip_filename="pocketbase_0.23.6_linux_amd64.zip"
base_dir="/opt/$hostname"
zip_file="/opt/$zip_filename"
service_file="/lib/systemd/system/$hostname.service"
caddy_file="/etc/caddy/Caddyfile"

# Create the directory for the new instance
echo "creating new directory"
mkdir -p "$base_dir"

# Copy and unzip PocketBase
echo "extracting in the new directory"
cp "$zip_file" "$base_dir"
unzip "$base_dir/$zip_filename" -d "$base_dir"

# Navigate to the new directory
cd "$base_dir" || exit

# Create a new admin account
echo "creating new admin account"
./pocketbase superuser create "$email" "$password"

# Find the next available port starting from 8091
echo "finding port"
port=8091
while lsof -i :$port &>/dev/null; do
  port=$((port + 1))
done
echo $port

# Create the systemd service unit
echo "creating new service"
cat <<EOF > "$service_file"
[Unit]
Description=$hostname

[Service]
Type=simple
User=root
Group=root
LimitNOFILE=4096
Restart=always
RestartSec=5s
StandardOutput=append:/var/log/errors.log
StandardError=append:/var/log/errors.log
ExecStart=$base_dir/pocketbase serve --http=0.0.0.0:$port

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
echo "starting service"
systemctl enable "$hostname.service"
systemctl start "$hostname.service"

# Add a block to the Caddyfile
echo "adding block to caddy"
if ! grep -q "$hostname" "$caddy_file"; then
  cat <<EOF >> "$caddy_file"
$hostname {
  reverse_proxy :$port
}
EOF
fi

# Reload Caddy configuration
echo "reloading caddy"
cd /etc/caddy/ || exit
caddy fmt --overwrite
caddy reload

# Print completion message
echo "PocketBase instance for $hostname has been set up successfully."
echo "Access it at http://$hostname"