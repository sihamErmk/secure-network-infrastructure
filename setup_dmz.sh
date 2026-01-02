#!/bin/bash

# 1. Installation (si pas déjà fait)
#apt update && apt install apache2 openssl -y

# 2. Création du dossier SSL et génération du certificat auto-signé
echo "[*] Génération du certificat SSL..."
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/apache.key \
    -out /etc/ssl/certs/apache.crt \
    -subj "/C=FR/ST=Paris/L=Paris/O=LSI3/CN=10.0.1.2"

# 3. Configuration du site SSL d'Apache
echo "[*] Configuration d'Apache HTTPS..."
# On met à jour les chemins des certificats dans la config par défaut
sed -i 's|/etc/ssl/certs/ssl-cert-snakeoil.pem|/etc/ssl/certs/apache.crt|g' /etc/apache2/sites-available/default-ssl.conf
sed -i 's|/etc/ssl/private/ssl-cert-snakeoil.key|/etc/ssl/private/apache.key|g' /etc/apache2/sites-available/default-ssl.conf

# 4. Activation des modules et du site
a2enmod ssl > /dev/null
a2enmod rewrite > /dev/null
a2ensite default-ssl > /dev/null

# 5. Configuration de la redirection HTTP (80) -> HTTPS (443)
# On modifie le VirtualHost 80 pour rediriger
cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    ServerName 10.0.1.2
    Redirect permanent / https://10.0.1.2/
</VirtualHost>
EOF

# 6. Redémarrage du service
service apache2 restart
echo "[OK] Serveur DMZ configuré en HTTPS (10.0.1.2)"