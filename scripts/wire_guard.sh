#!/bin/bash

# Set up WireGuard Server

export DEBIAN_FRONTEND=noninteractive

apt update && apt upgrade -y
apt install wireguard python3 python3-pip python3-venv -y

# Check if WireGuard is already configured
if [ ! -f "/etc/wireguard/wg0.conf" ]; then
    private_key=$(wg genkey)

    echo "$private_key" > /etc/wireguard/private.key
    chmod go= /etc/wireguard/private.key
    cat /etc/wireguard/private.key | wg pubkey | tee /etc/wireguard/public.key

    wireguard_config="[Interface]
PrivateKey = $private_key
Address = 10.0.0.4/24
ListenPort = 51820
SaveConfig = true

PostUp = iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE
PreDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE"

    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p

    echo "$wireguard_config" > /etc/wireguard/wg0.conf

    systemctl enable wg-quick@wg0.service && systemctl start wg-quick@wg0.service
    echo "WireGuard has been configured and started."
else
    echo "WireGuard configuration already exists. Skipping configuration."
    systemctl restart wg-quick@wg0.service
    echo "WireGuard service restarted."
fi

# Install Django Server

# Check if the project directory already exists
if [ ! -d "/server/" ]; then
    git clone https://github.com/${github_organization}/${github_repository}.git /server/
else
    echo "Project directory already exists. Skipping git clone."
fi

cd /server/

# Check if the virtual environment already exists
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "Virtual environment created."
else
    echo "Virtual environment already exists. Skipping creation."
fi

source ./venv/bin/activate
pip3 install -r ./requirements.txt

# Run migrations and create superuser if the database doesn't exist
if [ ! -f "db.sqlite3" ]; then
    python3 ./manage.py makemigrations api
    python3 ./manage.py migrate
    DJANGO_SUPERUSER_PASSWORD=WireGuard@443 python3 ./manage.py createsuperuser --noinput --username=admin --email=admin@papercloud.tech
else
    echo "Database already exists. Skipping migrations and superuser creation."
fi

python3 ./manage.py runserver 0.0.0.0:80 > /var/log/server.log 2>&1 &
echo "Django server started."

# Set up a Systemd Service to Run the Script at Every BootL
script_path="/usr/local/bin/wireguard_setup.sh"

# Create a Systemd Service to Run the Script at Every Boot
cat <<EOF | sudo tee /etc/systemd/system/wireguard-setup.service
[Unit]
Description=WireGuard and Django Setup
After=network.target

[Service]
Type=oneshot
ExecStart=$script_path
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

# Move the Script to a Permanent Location and Set Executable Permissions
if [ ! -f "$script_path" ]; then
    sudo mv $0 $script_path
    sudo chmod +x $script_path
else
    Lecho "WireGuard setup script already exists at $script_path. Skipping move."
fi

# Enable the Systemd Service to Run at Startup
sudo systemctl daemon-reload
sudo systemctl enable wireguard-setup.service
sudo systemctl start wireguard-setup.service
