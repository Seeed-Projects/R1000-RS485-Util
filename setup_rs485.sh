#!/bin/bash

# Prompt for sudo password
echo "Please enter your sudo password: "
read -s SUDO_PASSWORD

# Function to run commands with sudo and password
run_with_sudo() {
  echo "$SUDO_PASSWORD" | sudo -S "$@"
}

# Step 0: Cleanup previous installations if they exist
run_with_sudo systemctl disable start_rs485.service
run_with_sudo systemctl daemon-reload

# Delete existing files and directories if they exist
[ -d "seeed-linux-dtoverlays" ] && run_with_sudo rm -rf seeed-linux-dtoverlays
[ -f "/usr/local/bin/start_rs485.sh" ] && run_with_sudo rm -f /usr/local/bin/start_rs485.sh
[ -f "/usr/bin/rs485_DE" ] && run_with_sudo rm -f /usr/bin/rs485_DE
[ -f "/etc/systemd/system/start_rs485.service" ] && run_with_sudo rm -f /etc/systemd/system/start_rs485.service

# Step 1: Install libgpiod-dev
run_with_sudo apt-get update
run_with_sudo apt-get install -y libgpiod-dev

# Step 2: Install and make the driver
git clone https://github.com/Seeed-Studio/seeed-linux-dtoverlays.git
cd seeed-linux-dtoverlays/tools/rs485_control_DE/
gcc -o rs485_DE rs485_DE.c -lgpiod
run_with_sudo cp rs485_DE /usr/bin/
cd -

# Step 3: Create a bootup script
LOGFILE=/var/log/setup_rs485.log

echo "Starting setup at $(date)" | run_with_sudo tee -a $LOGFILE > /dev/null

# Create the startup script
echo "$SUDO_PASSWORD" | sudo -S tee /usr/local/bin/start_rs485.sh > /dev/null << 'EOF'
#!/bin/bash

# Log file
LOGFILE=/var/log/start_rs485.log

# Function to start rs485_DE instances
start_rs485_instances() {
  echo "Starting rs485_DE instances at $(date)" >> $LOGFILE 2>&1
  /usr/bin/rs485_DE /dev/ttyAMA2 /dev/gpiochip0 6 /dev/ttyAMA30 /dev/gpiochip2 12 &
  /usr/bin/rs485_DE /dev/ttyAMA5 /dev/gpiochip0 24 /dev/ttyAMA32 &
  /usr/bin/rs485_DE /dev/ttyAMA3 /dev/gpiochip0 17 /dev/ttyAMA31 &
  echo "rs485_DE instances started at $(date)" >> $LOGFILE 2>&1
}

# Start the instances
start_rs485_instances

# Keep the script running
while true; do
  sleep 60
done
EOF

# Make the startup script executable
run_with_sudo chmod +x /usr/local/bin/start_rs485.sh

# Create the systemd service file
echo "$SUDO_PASSWORD" | sudo -S tee /etc/systemd/system/start_rs485.service > /dev/null << 'EOF'
[Unit]
Description=Start Multiple RS485 DE Instances
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/start_rs485.sh
Restart=always
RestartSec=10
User=root
Group=root
AmbientCapabilities=CAP_SYS_RAWIO CAP_NET_ADMIN CAP_SYS_ADMIN CAP_DAC_OVERRIDE
CapabilityBoundingSet=CAP_SYS_RAWIO CAP_NET_ADMIN CAP_SYS_ADMIN CAP_DAC_OVERRIDE

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd manager configuration
run_with_sudo systemctl daemon-reload

# Enable the service to start at boot
run_with_sudo systemctl enable start_rs485.service

# Start the service immediately
run_with_sudo systemctl start start_rs485.service

echo "Setup completed at $(date)" | run_with_sudo tee -a $LOGFILE > /dev/null
