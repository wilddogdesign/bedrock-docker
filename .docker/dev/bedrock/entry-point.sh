#!/bin/bash

set -e

# Amend nGinx config
sed -i "s|_WP_HOME_|$WP_HOME|g" /etc/nginx/nginx.conf
sed -i "s|_ENV_|development|g" /etc/nginx/nginx.conf

# Set www-data local permissions (STRICTLY FOR LOCAL DEV)
usermod -u 1000 www-data
usermod -G staff www-data

# Amend php config
sed -i "s|listen = /run/php/php7.0-fpm.sock|listen = 9000|g" /etc/php/7.0/fpm/pool.d/www.conf
sed -i "s|;listen.allowed_clients|listen.allowed_clients|g" /etc/php/7.0/fpm/pool.d/www.conf

# Amend Wordpress init script
sed -i "s|_WP_HOME_|$WP_HOME|g" /init-wordpress.sh
sed -i "s|_MYSQL_DATABASE_|$MYSQL_DATABASE|g" /init-wordpress.sh
sed -i "s|_MYSQL_USER_|$MYSQL_USER|g" /init-wordpress.sh
sed -i "s|_MYSQL_PASSWORD_|$MYSQL_PASSWORD|g" /init-wordpress.sh

cd /var/www/

if ! [ -e .env.example -a -e composer.json ]; then
    echo >&2 "Bedrock is not installed. Downloading..."

    git init .
    git remote add -t \* -f origin https://github.com/roots/bedrock.git
    git checkout master

    cp .env.example .env

    sed -i "s|database_name|$MYSQL_DATABASE|g" .env
    sed -i "s|database_user|$MYSQL_USER|g" .env
    sed -i "s|database_password|$MYSQL_PASSWORD|g" .env
    sed -i "s|database_host|$MYSQL_LOCAL_HOST|g" .env
    sed -i "s|http://example.com|https://$WP_HOME|g" .env

    # sed -i "s|generateme|`openssl rand -base64 64`|g" .env

    echo >&2 "Done!"
fi

echo >&2 "Installing dependencies..."
composer up --no-dev --prefer-dist --no-interaction --optimize-autoloader
echo >&2 "Done! Dependencies have been installed"

cd /

/etc/init.d/php7.0-fpm start

dockerize -wait tcp://$MYSQL_LOCAL_HOST ./init-wordpress.sh

exec "$@"