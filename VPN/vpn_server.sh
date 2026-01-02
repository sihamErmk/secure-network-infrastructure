#!/bin/bash
# vpn_server_setup.sh - À lancer sur h_vpn

echo "[*] Configuration du serveur OpenVPN sur h_vpn..."

# Création du fichier de config OpenVPN
cat <<EOF > server.conf
dev tun
proto udp
port 1194
ca certs/ca.crt
cert certs/server.crt
key certs/server.key
dh certs/dh2048.pem
server 10.8.0.0 255.255.255.0
push "route 10.0.2.0 255.255.255.0"
topology subnet
client-to-client
keepalive 10 120
cipher AES-256-CBC
persist-key
persist-tun
verb 3
EOF

# Activation du routage sur le serveur VPN
sysctl -w net.ipv4.ip_forward=1
echo "[OK] Serveur VPN prêt (Config générée)."