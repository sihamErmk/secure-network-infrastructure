#!/bin/bash
# vpn_client.sh

echo "[*] Préparation du périphérique TUN sur h_wan..."
mkdir -p /dev/net
mknod /dev/net/tun c 10 200
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
echo "[OK] Log disponible dans vpn_client.log"
ip addr show tun0