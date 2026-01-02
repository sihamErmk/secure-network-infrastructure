#!/bin/bash
# Configuration Apache + SSL sur h_dmz

# 1. Nettoyage et Dossiers
service apache2 stop
mkdir -p /etc/ssl/private /etc/ssl/certs

# 2. Génération Certificat SSL
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/apache.key -out /etc/ssl/certs/apache.crt \
    -subj "/C=FR/O=LSI3/CN=10.0.1.2"

# 3. Correction du fichier ports (TRÈS IMPORTANT)
printf "Listen 80\nListen 443\n" > /etc/apache2/ports.conf

# 4. Config VirtualHost HTTPS
cat <<EOF > /etc/apache2/sites-available/default-ssl.conf
<VirtualHost *:443>
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/apache.crt
    SSLCertificateKeyFile /etc/ssl/private/apache.key
</VirtualHost>
EOF

# 5. Config Redirection HTTP -> HTTPS
cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    Redirect permanent / https://10.0.1.2/
</VirtualHost>
EOF

# 6. Activation modules et site
a2enmod ssl rewrite > /dev/null
a2ensite default-ssl 000-default > /dev/null

# 7. Redémarrage
service apache2 restart