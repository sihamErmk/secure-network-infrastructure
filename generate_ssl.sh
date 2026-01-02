#!/bin/bash
# generate_ssl.sh - Génération des certificats pour le serveur HTTPS

# 1. Création du dossier pour les certificats
mkdir -p certs

echo "[*] Génération de la clé privée (RSA 2048 bits)..."
openssl genrsa -out certs/server.key 2048

echo "[*] Génération du certificat auto-signé..."
# -subj : définit les informations du certificat sans poser de questions
# CN=10.0.1.2 est l'IP du serveur h_dmz
openssl req -new -x509 -key certs/server.key -out certs/server.crt -days 365 \
    -nodes -subj "/C=FR/ST=Paris/L=Paris/O=Projet_LSI3/CN=10.0.1.2"

# 2. Sécurisation de la clé privée
chmod 600 certs/server.key

echo "[OK] Certificats générés avec succès dans le dossier ./certs/"