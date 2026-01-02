# dmz_setup.sh
# Certificat SSL
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/apache.key -out /etc/ssl/certs/apache.crt \
    -subj "/C=FR/O=LSI3/CN=10.0.1.2"

# Redirection 80 -> 443
cat <<EOF > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
    Redirect permanent / https://10.0.1.2/
</VirtualHost>
EOF

# HTTPS Config
cat <<EOF > /etc/apache2/sites-available/default-ssl.conf
<VirtualHost *:443>
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/apache.crt
    SSLCertificateKeyFile /etc/ssl/private/apache.key
    DocumentRoot /var/www/html
</VirtualHost>
EOF

a2enmod ssl > /dev/null
a2ensite default-ssl > /dev/null
echo "Listen 80\nListen 443" > /etc/apache2/ports.conf
service apache2 restart