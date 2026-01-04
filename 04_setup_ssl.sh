#!/bin/bash
# 04_setup_ssl.sh - Configuration SSL/TLS pour serveur web DMZ

echo "=========================================="
echo "Configuration SSL/TLS (OpenSSL)"
echo "=========================================="

# Installation des outils nécessaires
echo "[1/5] Installation des paquets..."
sudo apt-get update -qq
sudo apt-get install -y openssl apache2 curl tcpdump

# Création du répertoire pour les certificats
echo "[2/5] Création des certificats SSL..."
SSL_DIR="/etc/ssl/lsi3"
sudo mkdir -p $SSL_DIR
cd $SSL_DIR

# Génération du certificat auto-signé
sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout server.key -out server.crt \
    -subj "/C=MA/ST=Tanger/L=Tanger/O=LSI3/OU=Security/CN=h_dmz.local" \
    2>/dev/null

echo "[OK] Certificat généré: $SSL_DIR/server.crt"

# Configuration Apache avec SSL
echo "[3/5] Configuration du serveur web..."

# Configuration du site HTTPS
sudo tee /etc/apache2/sites-available/secure-site.conf > /dev/null <<EOF
<VirtualHost *:443>
    ServerName h_dmz.local
    DocumentRoot /var/www/html
    
    SSLEngine on
    SSLCertificateFile $SSL_DIR/server.crt
    SSLCertificateKeyFile $SSL_DIR/server.key
    
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5:!3DES
    SSLHonorCipherOrder on
    
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/ssl_access.log combined
</VirtualHost>

<VirtualHost *:80>
    ServerName h_dmz.local
    Redirect permanent / https://h_dmz.local/
</VirtualHost>
EOF

# Page web de test
sudo tee /var/www/html/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>LSI3 Secure Web Server</title>
</head>
<body>
    <h1>Serveur Web Sécurisé - DMZ</h1>
    <p>Connexion SSL/TLS active</p>
    <p>Projet LSI3 - Infrastructure Réseau Sécurisée</p>
</body>
</html>
EOF

# Activation des modules et du site
echo "[4/5] Activation SSL..."
sudo a2enmod ssl rewrite
sudo a2ensite secure-site
sudo a2dissite 000-default

# Test de la configuration
echo "[5/5] Test de la configuration..."
sudo apache2ctl configtest

sudo systemctl restart apache2
sudo systemctl enable apache2

echo ""
echo "=========================================="
echo "Configuration SSL terminée!"
echo "=========================================="
echo "Certificat: $SSL_DIR/server.crt"
echo "Clé privée: $SSL_DIR/server.key"
echo ""
