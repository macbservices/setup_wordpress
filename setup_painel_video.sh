#!/bin/bash

# Verifica se o script está sendo executado como root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "Este script deve ser executado como root!" 1>&2
        exit 1
    fi
}

# Atualiza o sistema e instala dependências
install_dependencies() {
    echo "Atualizando pacotes e instalando dependências..."
    apt update && apt upgrade -y
    apt install -y nginx libnginx-mod-rtmp unzip ffmpeg mysql-server php-fpm php-mysql
}

# Configura o Nginx para WordPress e players
configure_nginx() {
    echo "Configurando Nginx para WordPress e players..."
    cat > /etc/nginx/sites-available/$DOMAIN <<EOL
server {
    listen 80;
    server_name $DOMAIN;

    # Configuração do WordPress
    root /var/www/$DOMAIN/wordpress;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Configuração dos players
    location /players {
        root /var/www/$DOMAIN;
        index index.html;
    }

    # Configuração para HLS
    location /live/ {
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
        root /var/www/hls/;
    }
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application live {
            live on;
            record off;

            hls on;
            hls_path /var/www/hls/live;
            hls_fragment 2s;
        }
    }
}
EOL

    ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
    mkdir -p /var/www/hls/live
    chown -R www-data:www-data /var/www/hls
    chmod -R 755 /var/www/hls
    systemctl restart nginx
}

# Instala o WordPress
install_wordpress() {
    echo "Instalando o WordPress..."
    wget https://wordpress.org/latest.zip -O /tmp/wordpress.zip
    unzip /tmp/wordpress.zip -d /tmp/
    mv /tmp/wordpress /var/www/$DOMAIN/wordpress
    chown -R www-data:www-data /var/www/$DOMAIN/wordpress
    chmod -R 755 /var/www/$DOMAIN/wordpress
}

# Configura o banco de dados para o WordPress
configure_database() {
    echo "Configurando banco de dados para o WordPress..."
    read -p "Digite o nome do banco de dados: " DB_NAME
    read -p "Digite o usuário do banco de dados: " DB_USER
    read -p "Digite a senha do banco de dados: " DB_PASSWORD

    mysql -u root -e "CREATE DATABASE $DB_NAME;"
    mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -u root -e "FLUSH PRIVILEGES;"
}

# Cria o site HTML com 10 players
create_players_site() {
    echo "Criando site HTML com 10 players..."
    mkdir -p /var/www/$DOMAIN/players
    cat > /var/www/$DOMAIN/players/index.html <<EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Painel de Vídeos</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            display: flex;
            flex-wrap: wrap;
            justify-content: center;
            background-color: #f4f4f4;
        }
        .player {
            margin: 10px;
            background: #000;
            border: 2px solid #ddd;
            border-radius: 8px;
            overflow: hidden;
        }
        video {
            display: block;
            width: 100%;
            height: auto;
        }
        .player-container {
            width: 32%;
            min-width: 300px;
        }
        .title {
            text-align: center;
            color: white;
            background: #333;
            padding: 5px;
            font-size: 16px;
        }
    </style>
</head>
<body>
EOL

    for i in $(seq 1 10); do
        cat >> /var/www/$DOMAIN/players/index.html <<EOL
    <div class="player-container">
        <div class="title">Canal $i</div>
        <div class="player">
            <video controls autoplay>
                <source src="http://$DOMAIN/live/canal$i/index.m3u8" type="application/x-mpegURL">
                Seu navegador não suporta este vídeo.
            </video>
        </div>
    </div>
EOL
    done

    cat >> /var/www/$DOMAIN/players/index.html <<EOL
</body>
</html>
EOL
}

# Função principal
main() {
    check_root

    echo "Bem-vindo à configuração automatizada!"
    read -p "Informe o domínio que você deseja usar (ex.: painel.macbvendas.com.br): " DOMAIN

    install_dependencies
    configure_nginx
    install_wordpress
    configure_database
    create_players_site

    echo "Configuração concluída!"
    echo "WordPress disponível em http://$DOMAIN"
    echo "Painel de vídeos disponível em http://$DOMAIN/players"
    echo "Transmita para RTMP: rtmp://$DOMAIN/live com as keys canal1, canal2, ..., canal10."
}

main
