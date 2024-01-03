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
Address = 10.0.0.0/24
ListenPort = 51820
SaveConfig = true

PostUp = iptables -t nat -I POSTROUTING -o eth0 -j MASQUERADE
PreDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE"

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

echo "$wireguard_config" > /etc/wireguard/wg0.conf

systemctl enable wg-quick@wg0.service && systemctl start wg-quick@wg0.service
systemctl status wg-quick@wg0.service

# Add Client Keygenerator Script

key_gen_script=$(cat <<'EOF'
#!/bin/bash
# Author: InferenceFailed Developers
# Created on: 27/12/2023
usage() {
  echo "Usage: $0 -c client_ip -s server_ip [-d dns] [-p tunnel_port]"
  exit 1
}   

serverpubkey() {
  cat /etc/wireguard/public.key
}

keygen() {
  local client_private_key=$(wg genkey)

  mkdir -p $workdir

  echo "$client_private_key" > $workdir/private.key
  chmod go= $workdir/private.key

  cat $workdir/private.key | wg pubkey > $workdir/public.key
}

confgen() {
  local client_config="[Interface]
PrivateKey = $1
Address = $2/32
DNS = $3

[Peer]
PublicKey = $4
AllowedIPs = 0.0.0.0/0
Endpoint = $5:$6"

  echo "$client_config" > $workdir/client.conf
}

dns="1.1.1.1,1.1.0.0"
tunnel_port=51820

while getopts ":c:s:pdh" opt; do
  case $opt in
    c)
      client_ip="$OPTARG"
      ;;
    d)
      dns="$OPTARG"
      ;;
    p)
      tunnel_port="$OPTARG"
      ;;
    s)
      server_ip="$OPTARG"
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option provided: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option '-$OPTARG' requires an argument." >&2
      usage
      ;;
  esac
done

workdir=/etc/wireguard/clients/$client_ip

keygen
confgen "$(cat $workdir/private.key)" "$client_ip" "$dns" "$(serverpubkey)" "$server_ip" "$tunnel_port"

wg set wg0 peer $(cat $workdir/public.key) allowed-ips $client_ip

EOF
)
echo "$key_gen_script" >> /usr/local/bin/wireguard-keygen.sh

chmod +x /usr/local/bin/wireguard-keygen.sh


key_gen_script=$(cat <<'EOF'
#!/bin/bash
# Author: InferenceFailed Developers
# Created on: 27/12/2023
usage() {
  echo "Usage: $0 -c client_ip -s server_ip [-d dns] [-p tunnel_port]"
  exit 1
}   

serverpubkey() {
  cat /etc/wireguard/public.key
}

keygen() {
  local client_private_key=$(wg genkey)

  mkdir -p $workdir

  echo "$client_private_key" > $workdir/private.key
  chmod go= $workdir/private.key

  cat $workdir/private.key | wg pubkey > $workdir/public.key
}

confgen() {
  local client_config="[Interface]
PrivateKey = $1
Address = $2/32
DNS = $3

[Peer]
PublicKey = $4
AllowedIPs = 0.0.0.0/0
Endpoint = $5:$6"

  echo "$client_config" > $workdir/client.conf
}

dns="1.1.1.1,1.1.0.0"
tunnel_port=51820

while getopts ":c:s:pdh" opt; do
  case $opt in
    c)
      client_ip="$OPTARG"
      ;;
    d)
      dns="$OPTARG"
      ;;
    p)
      tunnel_port="$OPTARG"
      ;;
    s)
      server_ip="$OPTARG"
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option provided: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option '-$OPTARG' requires an argument." >&2
      usage
      ;;
  esac
done

workdir=/etc/wireguard/clients/$client_ip

keygen
confgen "$(cat $workdir/private.key)" "$client_ip" "$dns" "$(serverpubkey)" "$server_ip" "$tunnel_port"

wg set wg0 peer $(cat $workdir/public.key) allowed-ips $client_ip

EOF
)

# Install django Server

git clone https://${github_pat}@github.com/${github_organization}/${github_repository}.git /server/
cd /server/

python3 -m venv venv && source ./venv/bin/activate
pip3 install -r ./requirements.txt
python3 ./manage.py makemigrations api
python3 ./manage.py migrate --run-syncdb
DJANGO_SUPERUSER_PASSWORD=WireGuard@443 python3 ./manage.py createsuperuser --noinput --username=admin --email=admin@openkart.com
python3 ./manage.py runserver 0.0.0.0:80 > /var/log/server.log 2>&1 &

