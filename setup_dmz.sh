#!/bin/bash
# setup_dmz_python.sh - Configuration et lancement du service Web

echo "[*] Initialisation du service DMZ..."

# 1. Vérification/Génération des certificats
if [ ! -f "certs/server.crt" ]; then
    echo "[!] Certificats manquants. Appel de generate_ssl.sh..."
    bash generate_ssl.sh
fi

# 2. Création d'une page d'accueil de test
echo "<html><body><h1>Zone Demilitarisee (DMZ) Securisee</h1><p>Modele Zero Trust - LSI3</p></body></html>" > index.html

# 3. Arrêt des anciens processus Python ou Apache pour libérer les ports
fuser -k 80/tcp 2>/dev/null
fuser -k 443/tcp 2>/dev/null

# 4. Lancement du serveur Python (secure_server.py)
# On utilise nohup pour qu'il continue de tourner en arrière-plan
echo "[*] Lancement du serveur Web Python (HTTPS + Redirection)..."
nohup python3 secure_server.py > server.log 2>&1 &

echo "[OK] Le serveur tourne. PID: $!"
echo "[i] Consultez server.log pour voir les connexions."