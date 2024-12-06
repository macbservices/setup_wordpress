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
    apt install -y nginx libnginx-mod-rtmp unzip ffmpeg
}

# Configura o Nginx com suporte a RTMP e HLS
configure_nginx_rtmp() {
    echo "Configurando Nginx com RTMP..."
    cat > /etc/nginx/nginx.conf <<EOL
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 768;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    sendfile on;
    keepalive_timeout 65;

    server {
        listen 80;
        server_name $DOMAIN;

        root /var/www/$DOMAIN;
        index index.html;

        location / {
            try_files \$uri \$uri/ =404;
        }

        # HLS
        location /live/ {
            types {
                application/vnd.apple.mpegurl m3u8;
                video/mp2t ts;
            }
            root /var/www/hls/;
        }
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

    mkdir -p /var/www/hls/live
    chown -R www-data:www-data /var/www/hls
    chmod -R 755 /var/www/hls
    systemctl restart nginx
}

# Cria o site HTML com 10 players
create_site() {
    echo "Criando site HTML..."
    mkdir -p /var/www/$DOMAIN
    cat > /var/www/$DOMAIN/index.html <<EOL
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
        cat >> /var/www/$DOMAIN/index.html <<EOL
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

    cat >> /var/www/$DOMAIN/index.html <<EOL
</body>
</html>
EOL
}

# Permissões para o site
set_permissions() {
    echo "Definindo permissões para o site..."
    chown -R www-data:www-data /var/www/$DOMAIN
    chmod -R 755 /var/www/$DOMAIN
}

# Configura permissões para o script
setup_script_permissions() {
    echo "Configurando permissões para o script..."
    chmod +x $0
}

# Função principal
main() {
    check_root

    echo "Bem-vindo à configuração automatizada do painel de vídeos!"
    read -p "Informe o domínio que você deseja usar (ex.: painel.macbvendas.com.br): " DOMAIN

    install_dependencies
    configure_nginx_rtmp
    create_site
    set_permissions
    setup_script_permissions

    echo "Configuração concluída!"
    echo "Inicie suas transmissões no OBS Studio utilizando a URL RTMP: rtmp://$DOMAIN/live"
    echo "Cada stream deve usar uma 'Stream Key' como: canal1, canal2, ..., canal10."
    echo "Acesse o painel em http://$DOMAIN"
}

main
