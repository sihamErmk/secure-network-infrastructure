#!/bin/bash
# vpn_server.sh

echo "[*] Préparation du périphérique TUN sur h_vpn..."
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

echo "[*] Création de la configuration serveur..."
cat <<EOF > server.conf
dev tun
proto udp
port 1194
ca certs/ca.crt
cert certs/server.crt
key certs/server.key
dh certs/dh2048.pem
server 10.8.0.0 255.255.255.0
topology subnet
push "route 10.0.2.0 255.255.255.0"
cipher AES-256-CBC
verb 3
keepalive 10 120
persist-key
persist-tun
EOF

echo "[*] Démarrage du serveur OpenVPN..."
openvpn --config server.conf --daemon --log vpn_server.log
sleep 2
echo "[OK] Log disponible dans vpn_server.log"
ip addr show tun0