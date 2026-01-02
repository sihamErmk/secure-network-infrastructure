#!/bin/bash
# vpn_client_setup.sh - À lancer sur h_wan

echo "[*] Configuration du client VPN sur h_wan..."

cat <<EOF > client.ovpn
client
dev tun
proto udp
remote 10.0.3.2 1194
resolv-retry infinite
nobind
persist-key
persist-tun
ca certs/ca.crt
cert certs/client.crt
key certs/client.key
cipher AES-256-CBC
verb 3
EOF

echo "[OK] Profil client VPN prêt (client.ovpn)."