#!/bin/bash

set -e

# Amend nGinx config
sed -i "s|_WP_HOME_|$WP_HOME|g" /etc/nginx/nginx.conf
sed -i "s|_ENV_|development|g" /etc/nginx/nginx.conf

# Set www-data local permissions (STRICTLY FOR LOCAL DEV)
# usermod -u 1000 www-data
# usermod -G staff www-data

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

    # sed -i "s|generateme|`openssl rand -base64 64`|g" .env

    echo >&2 "Amending Timber to must use plugins"
    jq '.extra ."installer-paths" ."web/app/mu-plugins/{$name}/" |= .+ ["wpackagist-plugin/timber-library"]' composer.json > newcomposer.json && mv newcomposer.json composer.json
    jq '.extra ."installer-paths" ."web/app/mu-plugins/{$name}/" |= .+ ["wpackagist-plugin/cmb2"]' composer.json > newcomposer.json && mv newcomposer.json composer.json
    echo >&2 "Amended Timber to must use plugins"

    composer require wpackagist-plugin/timber-library wpackagist-plugin/cmb2 --prefer-dist --optimize-autoloader

    echo >&2 "Done!"
fi

if ! [ -e .env ]; then
    echo >&2 "Creating environment file..."

    cat > .env <<EOF
DB_NAME=$MYSQL_DATABASE
DB_USER=$MYSQL_USER
DB_PASSWORD=$MYSQL_PASSWORD
DB_HOST=$MYSQL_LOCAL_HOST

# WP_CACHE=true

WP_ENV=$WP_ENV
WP_HOME=$WP_HOME
WP_SITEURL=$WP_SITEURL

AUTH_KEY='$(openssl rand -base64 48)'
SECURE_AUTH_KEY='$(openssl rand -base64 48)'
LOGGED_IN_KEY='$(openssl rand -base64 48)'
NONCE_KEY='$(openssl rand -base64 48)'
AUTH_SALT='$(openssl rand -base64 48)'
SECURE_AUTH_SALT='$(openssl rand -base64 48)'
LOGGED_IN_SALT='$(openssl rand -base64 48)'
NONCE_SALT='$(openssl rand -base64 48)'
EOF

fi

echo >&2 "Installing dependencies..."
composer up --no-dev --prefer-dist --no-interaction --optimize-autoloader
echo >&2 "Done! Dependencies have been installed"

cd /var/www/web/app/themes

if ! [ -d "$WP_THEME" ]; then
    echo >&2 "Theme doesn't exist. Downloading..."
    git clone https://github.com/timber/starter-theme.git $WP_THEME && \
    cd $WP_THEME && \
    rm -Rf tests/ bin/ .git/ static/site.js .gitignore .travis.yml phpunit.xml composer.json composer.lock
    echo >&2 "Done!"
fi

echo >&2 "Linking in static assets..."
cd /var/www/web/app/themes/$WP_THEME/static

if ! [ -e css ]; then
    ln -s /var/templates/dist/assets/css
fi
if ! [ -e js ]; then
    ln -s /var/templates/dist/assets/js
fi
if ! [ -e icons ]; then
    ln -s /var/templates/dist/assets/icons
fi

cd /

/etc/init.d/php7.0-fpm start

dockerize -wait tcp://$MYSQL_LOCAL_HOST ./init-wordpress.sh

exec "$@"