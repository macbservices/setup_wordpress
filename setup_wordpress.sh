#!/bin/bash

# Checar se o usuário é root
if [[ $EUID -ne 0 ]]; then
   echo "Este script deve ser executado como root."
   exit 1
fi

# Variáveis para personalização
echo "### CONFIGURAÇÃO INICIAL ###"
read -p "Digite o domínio para o WordPress (exemplo: painel.macbvendas.com.br): " DOMAIN
read -p "Digite o IP público que o domínio usará (exemplo: 170.254.135.110): " PUBLIC_IP
read -p "Digite o IP interno da VPS (exemplo: 100.102.90.90): " INTERNAL_IP
read -p "Digite o usuário do banco de dados do WordPress: " DB_USER
read -p "Digite a senha do banco de dados do WordPress: " DB_PASS
read -p "Digite o nome do banco de dados do WordPress: " DB_NAME

# Atualizar pacotes e instalar dependências
echo "Atualizando pacotes e instalando dependências..."
apt update && apt upgrade -y
apt install -y nginx mysql-server php-fpm php-mysql unzip curl ufw

# Configurar firewall
echo "Configurando firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# Configurar MySQL
echo "Configurando MySQL..."
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "Banco de dados $DB_NAME e usuário $DB_USER configurados com sucesso."

# Baixar e configurar WordPress
echo "Baixando e configurando WordPress..."
wget -q https://wordpress.org/latest.zip -O /tmp/wordpress.zip
unzip -q /tmp/wordpress.zip -d /var/www/
mv /var/www/wordpress /var/www/$DOMAIN

# Configurar permissões
echo "Configurando permissões do WordPress..."
chown -R www-data:www-data /var/www/$DOMAIN
chmod -R 755 /var/www/$DOMAIN

# Configurar wp-config.php
echo "Configurando wp-config.php..."
cp /var/www/$DOMAIN/wp-config-sample.php /var/www/$DOMAIN/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" /var/www/$DOMAIN/wp-config.php
sed -i "s/username_here/$DB_USER/" /var/www/$DOMAIN/wp-config.php
sed -i "s/password_here/$DB_PASS/" /var/www/$DOMAIN/wp-config.php

# Configurar Nginx
echo "Configurando Nginx para o domínio $DOMAIN..."
cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/$DOMAIN;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Ativar configuração do Nginx
ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Configurar HTTPS com Certbot
echo "Instalando e configurando Certbot para HTTPS..."
apt install -y certbot python3-certbot-nginx
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

# Finalizar
echo "Instalação concluída com sucesso!"
echo "Acesse o WordPress no domínio: http://$DOMAIN ou https://$DOMAIN"
