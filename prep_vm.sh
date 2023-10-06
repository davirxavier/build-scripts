#!/bin/bash

DOMAIN_NAME=$1
REAL_SERVER_IP=$2
ADMIN_EMAIL=$3
NO_IP_USER=$4
NO_IP_PASS=$5
NO_IP_DOMAIN=$6
ZEROTIER_NETWORK=$7

sudo apt-get -y install nginx snapd curl wget
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
certbot --non-interactive \
    --agree-tos \
    --no-eff-email \
    --no-redirect \
    --email "$ADMIN_EMAIL" \
    --domains "$DOMAIN_NAME" \
    --nginx

wget https://dmej8g5cpdyqd.cloudfront.net/downloads/noip-duc_3.0.0-beta.7.tar.gz
tar xf noip-duc_3.0.0-beta.7.tar.gz
cd noip-duc_3.0.0-beta.7/binaries && sudo apt install ./noip-duc_3.0.0-beta.7_amd64.deb

cat <<EOF | sudo tee /etc/default/noip-duc
NOIP_USERNAME=${NO_IP_USER}
NOIP_PASSWORD=${NO_IP_PASS}
NOIP_HOSTNAMES=${NO_IP_DOMAIN}
EOF

sudo systemctl daemon-reload
sudo systemctl enable noip-duc
sudo systemctl start noip-duc

cat <<EOF | sudo tee /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    #root /var/www/html;

    # Add index.php to the list if you are using PHP
    index index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
            # First attempt to serve request as file, then
            # as directory, then fall back to displaying a 404.
            try_files \$uri \$uri/ =404;
    }
}

server {
    listen 80 ;
    listen [::]:80 ;

    #root /var/www/html;
    #index index.html index.htm index.nginx-debian.html;

    server_name ${DOMAIN_NAME}; # managed by Certbot

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    location / {
        proxy_pass http://${REAL_SERVER_IP}:46600;
    }

    location ~ ^/epr(.*)$ {
        proxy_pass http://${REAL_SERVER_IP}:46603/epr$1;
    }
}
EOF

sudo systemctl restart nginx

curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/master/doc/contact%40zerotier.com.gpg' | gpg --import && \
if z=$(curl -s 'https://install.zerotier.com/' | gpg); then echo "$z" | sudo bash; fi
sudo zerotier-cli join "${ZEROTIER_NETWORK}"