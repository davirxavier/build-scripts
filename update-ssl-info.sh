#!/bin/bash

DOMAIN_NAME=$1
VALUE_FILE="/tmp/update-ssl-info-saved.dat"

if [ ! -f "$VALUE_FILE" ]; then
    LAST_REAL_IP="$(curl 'https://api.ipify.org')"
else
    LAST_REAL_IP=$(cat "$VALUE_FILE")
fi

REAL_IP=$(curl 'https://api.ipify.org')

if [[ "$REAL_IP" == "$LAST_REAL_IP" ]]; then
  sed -i "s/\(RewriteRule (\.\*) \?\)[^%]\+\(%{REQUEST_URI}\)/\1 ${DOMAIN_NAME}\2/" /etc/apache2/sites-available/000-default.conf
  sed -i "s/\(RewriteRule (\.\*) \?\)[^%]\+\(%{REQUEST_URI}\)/\1 ${DOMAIN_NAME}\2/" /etc/apache2/sites-available/000-default-le-ssl.conf
  sed -i "s/\(SSLCertificateFile \/etc\/letsencrypt\/live\/\)[^\/]\+\(\/fullchain.pem\)/\1${DOMAIN_NAME}\2/" /etc/apache2/sites-available/000-default-le-ssl.conf
  sed -i "s/\(SSLCertificateKeyFile \/etc\/letsencrypt\/live\/\)[^\/]\+\(\/privkey.pem\)/\1${DOMAIN_NAME}\2/" /etc/apache2/sites-available/000-default-le-ssl.conf
  sed -i "s/\(ServerName \)[0-9]\{0,3\}\.[0-9]\{0,3\}\.[0-9]\{0,3\}\.[0-9]\{0,3\}/\1${REAL_IP}/" /etc/apache2/sites-available/000-default-le-ssl.conf
  sed -i "s/\(ServerName *\)[a-zA-Z\.]\+/\1${DOMAIN_NAME}/" /etc/apache2/sites-available/000-default-le-ssl.conf
  service apache2 restart
fi

echo "$REAL_IP" > $VALUE_FILE