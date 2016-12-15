#!/bin/bash
# USER=admin
# USER_PASS=`openssl rand -base64 8`

cd /var/www/web

if ! $(wp core is-installed --allow-root); then
  echo >&2 "Switching Wordpress on..."
  wp core config --dbname=_MYSQL_DATABASE_ \
                 --dbuser=_MYSQL_USER_ \
                 --dbpass=_MYSQL_PASSWORD_ \
                 --allow-root
  wp core install --url=https://_WP_HOME_/cms/ \
                  --title=_WP_TITLE_ \
                  --admin_user=_WP_USER_ \
                  --admin_password=_WP_PASS_ \
                  --admin_email=_WP_EMAIL_ \
                  --allow-root
  echo >&2 "Done!"
  echo >&2 "========================="
  echo >&2 "User: _WP_USER_"
  echo >&2 "Pass: _WP_PASS_"
  echo >&2 "========================="
else
  echo >&2 "Wordpress installed. Carrying on..."
fi

echo >&2 "Activating _WP_THEME_..."
wp theme activate _WP_THEME_ --allow-root

cd /