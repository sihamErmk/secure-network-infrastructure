#!/bin/bash
# vpn_client.sh - Version corrigée pour acheminer le trafic vers LAN/DMZ

echo "[*] Préparation du périphérique TUN sur h_wan..."
mkdir -p /dev/net
mknod /dev/net/tun c 10 200 2>/dev/null
chmod 600 /dev/net/tun

echo "[*] Création de la configuration client..."
cat <<EOF > client.ovpn
client
dev tun
proto udp
remote 10.0.3.2 1194
resolv-retry infinite
nobind
ca certs/ca.crt
cert certs/client.crt
key certs/client.key
cipher AES-256-CBC
verb 3
EOF

echo "[*] Démarrage du client OpenVPN..."
openvpn --config client.ovpn --daemon --log vpn_client.log
sleep 5

echo "[*] Configuration des routes LAN/DMZ via le tunnel VPN..."
# Route LAN (10.0.2.0/24) via tunnel tun0
ip route add 10.0.2.0/24 dev tun0
# Route DMZ (10.0.1.0/24) via tunnel tun0
ip route add 10.0.1.0/24 dev tun0
# Optionnel : route ADM (10.0.4.0/24) si nécessaire
ip route add 10.0.4.0/24 dev tun0

echo "[OK] Log disponible dans vpn_client.log"
ip addr show tun0
ip route show
