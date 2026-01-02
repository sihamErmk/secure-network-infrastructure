#!/bin/bash
mkdir -p certs
cd certs

echo "[*] Génération de l'Autorité de Certification (CA)..."
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt -subj "/CN=VPN-CA"

echo "[*] Génération du certificat SERVEUR..."
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=VPN-Server"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365

echo "[*] Génération du certificat CLIENT..."
openssl genrsa -out client.key 2048
openssl req -new -key client.key -out client.csr -subj "/CN=VPN-Client"
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365

echo "[*] Génération des paramètres Diffie-Hellman..."
openssl dhparam -out dh2048.pem 2048
cd ..
echo "[OK] Certificats créés dans le dossier ./certs/"