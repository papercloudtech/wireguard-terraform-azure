#!/bin/sh

# Set up WireGuard Server

export DEBIAN_FRONTEND=noninteractive

apt update && apt upgrade -y
apt install wireguard python3 python3-pip python3-venv -y

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
systemctl status wg-quick@wg0.service

# Install django Server

git clone https://github.com/${github_organization}/${github_repository}.git /server/
cd /server/

python3 -m venv venv && source ./venv/bin/activate
pip3 install -r ./requirements.txt
python3 ./manage.py makemigrations api
python3 ./manage.py migrate
DJANGO_SUPERUSER_PASSWORD=WireGuard@443 python3 ./manage.py createsuperuser --noinput --username=admin --email=admin@openkart.com
python3 ./manage.py runserver 0.0.0.0:80 > /var/log/server.log 2>&1 &

