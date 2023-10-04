#!/bin/bash

DOMAIN_NAME=$1
REAL_IP=$2
ADMIN_EMAIL=$3
UPDATE_SCRIPT_URL=$4

sudo apt-get -y install apache2 snapd curl
sudo a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot --apache

cat <<EOF | sudo tee /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule (.*) ${DOMAIN_NAME}%{REQUEST_URI}
</VirtualHost>
EOF

cat <<EOF | sudo tee /etc/apache2/sites-available/000-default-le-ssl.conf
<IfModule mod_ssl.c>

<VirtualHost *:443>
  ServerName ${REAL_IP}
  RewriteEngine On
  RewriteCond %{HTTPS} on
  RewriteRule (.*) ${DOMAIN_NAME}%{REQUEST_URI}
  SSLCertificateFile /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem
</VirtualHost>

<VirtualHost *:443>
  ServerAdmin ${ADMIN_EMAIL}
  ErrorLog ${APACHE_LOG_DIR}/error.log
  CustomLog ${APACHE_LOG_DIR}/access.log combined
  ServerName ${DOMAIN_NAME}
  SSLCertificateFile /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem
  SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem
  Include /etc/letsencrypt/options-ssl-apache.conf

  ProxyPreserveHost On

  ProxyPass /service1 http://192.168.13.5:5555/service1
  ProxyPassReverse /service1 http://192.168.13.5:5555/service1
  ProxyPass / http://192.168.13.5:5555/
  ProxyPassReverse / http://192.168.13.5:5555/
</VirtualHost>
</IfModule>
EOF

sudo service apache2 restart

curl "${UPDATE_SCRIPT_URL}" | sudo tee /usr/bin/update_apache_ssl_info.sh
sudo chmod +x /usr/bin/update_apache_ssl_info.sh
echo "*/10 * * * * sudo /bin/bash /usr/bin/update_apache_ssl_info.sh" | sudo tee -a /etc/crontab