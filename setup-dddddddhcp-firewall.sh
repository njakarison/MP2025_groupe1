#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté avec les droits root. Utilisez 'sudo ./setup-dhcp-firewall.sh'"
  exit 1
fi

echo "[1/8] Demande des informations de configuration réseau pour le DHCP..."
read -p "Adresse réseau (ex: 192.168.100.0): " RESEAU
read -p "Masque de sous-réseau (ex: 255.255.255.0): " NETMASK
read -p "Adresse IP de début (ex: 192.168.100.100): " IP_DEBUT
read -p "Adresse IP de fin (ex: 192.168.100.200): " IP_FIN
read -p "Passerelle (ex: 192.168.100.1): " GATEWAY
read -p "DNS (ex: 8.8.8.8): " DNS

echo "[2/8] Mise à jour du système et installation de Docker..."
apt update && apt upgrade -y
apt install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian   $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |   tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[3/8] Nettoyage des anciens fichiers (si présents)..."
rm -rf docker-firewall
docker rm -f mon-serveur-dhcp 2>/dev/null || true
docker image rm dhcp-firewall 2>/dev/null || true

echo "[4/8] Création des fichiers Docker..."
mkdir -p docker-firewall
cd docker-firewall

# script-firewall.sh
cat > script-firewall.sh << 'EOF'
#!/bin/bash
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p icmp --icmp-type 8 -j DROP
netfilter-persistent save
EOF

# script-dhcp.sh
cat > script-dhcp.sh << EOF
#!/bin/bash
echo 'DHCPDv4_CONF=/etc/dhcp/dhcpd.conf' > /etc/default/isc-dhcp-server
echo 'INTERFACESv4="enp0s3"' >> /etc/default/isc-dhcp-server

cat <<EOL > /etc/dhcp/dhcpd.conf
option domain-name "gerioux.com";
default-lease-time 345600;
max-lease-time 691200;
authoritative;
log-facility local7;

subnet $RESEAU netmask $NETMASK {
    range $IP_DEBUT $IP_FIN;
    option domain-name-servers $DNS;
    option routers $GATEWAY;
}
EOL

systemctl restart isc-dhcp-server.service
EOF

# Dockerfile
cat > Dockerfile << 'EOF'
FROM debian:stable-slim

RUN apt update && apt install -y iptables iptables-persistent isc-dhcp-server net-tools nano systemctl

COPY script-dhcp.sh /root/script-dhcp.sh
COPY script-firewall.sh /root/script-firewall.sh

RUN chmod +x /root/script-dhcp.sh /root/script-firewall.sh

CMD /root/script-firewall.sh && /root/script-dhcp.sh && tail -f /dev/null
EOF

chmod +x script-dhcp.sh script-firewall.sh

echo "[5/8] Construction de l’image Docker..."
docker build -t dhcp-firewall .

echo "[6/8] Lancement du conteneur DHCP + Pare-feu..."
docker run --rm --net=host --cap-add=NET_ADMIN --name mon-serveur-dhcp dhcp-firewall
