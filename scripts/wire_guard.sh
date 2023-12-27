#!/bin/sh

export DEBIAN_FRONTEND=noninteractive

apt update && apt upgrade -y
apt install wireguard -y

private_key=$(wg genkey)

echo "$private_key" > /etc/wireguard/private.key
chmod go= /etc/wireguard/private.key
cat /etc/wireguard/private.key | wg pubkey | tee /etc/wireguard/public.key

wireguard_config="[Interface]
PrivateKey = $private_key
Address = 10.0.0.1/24
ListenPort = 51820
SaveConfig = true

PostUp = iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE
PreDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE"

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

echo "$wireguard_config" > /etc/wireguard/wg0.conf

systemctl enable wg-quick@wg0.service && systemctl start wg-quick@wg0.service
systemctl status wg-quick@wg0.service