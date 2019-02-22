#!/bin/bash

atd

#Run php-fpm on startup
/etc/init.d/php7.2-fpm start

#Run nginx on startup
/etc/init.d/nginx start


# Check if PHP database config exists. If not, copy in the default config
if [ -f /config/config.php ]; then
  echo "Using existing PHP database config file."
  echo "/opt/observium/discovery.php -u" | at -M now + 1 minute
else
  echo "Loading PHP config from default."
  mkdir -p /config/databases
  cp /opt/observium/config.php.default /config/config.php
  chown nobody:users /config/config.php
  PW=$(pwgen -1snc 32)
  sed -i -e 's/PASSWORD/'$PW'/g' /config/config.php
  sed -i -e 's/USERNAME/observium/g' /config/config.php
  sed -i -e 's/localhost/database1/g' /config/config.php

fi

#Check if database exist
USER=$(cat /config/config.php | grep -m 1 "'db_user'" | sed -r 's/.{26}//;s/.$//' | sed 's/'"'"'//g')
PW=$(cat /config/config.php | grep -m 1 "'db_pass'" | sed -r 's/.*(.{34})/\1/;s/.{2}$//')
DATABASE=$(cat /config/config.php | grep -m 1 "'db_name'" | sed -r 's/.{26}//;s/.$//' | sed 's/'"'"'//g')
RESULT=`mysql -u$USER -p$PW -e "SHOW DATABASES" -h database1 | grep $DATABASE`
if [ "$RESULT" == "$DATABASE" ]; then
   echo "Database exists"
else
   echo "Database not exists"
   echo "Creating database...."
   mysql -u$USER -p$PW -h database1 -e "CREATE DATABASE IF NOT EXISTS observium DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
   echo "Creating database user."
   mysql -u$USER -p$PW -h database1 -e "CREATE USER 'observium'@'%' IDENTIFIED BY '$PW'"
   echo "Granting database access to 'observium' user for localhost."
   mysql -u$USER -p$PW -h database1 -e "GRANT ALL PRIVILEGES ON observium.* TO 'observium'@'%'"
   mysql -u$USER -p$PW -h database1 -e "FLUSH PRIVILEGES"
   cd /opt/observium
   echo "Running Observium's initial script."
   ./discovery.php -u
   ./adduser.php observium observium 10
fi


ln -s /config/config.php /opt/observium/config.php
chown nobody:users -R /opt/observium
chmod 755 -R /opt/observium

if [ -f /etc/container_environment/TZ ] ; then
  sed -i "s#\;date\.timezone\ \=#date\.timezone\ \=\ $TZ#g" /etc/php/7.2/cli/php.ini
  sed -i "s#\;date\.timezone\ \=#date\.timezone\ \=\ $TZ#g" /etc/php/7.2/fpm/php.ini
else
  echo "Timezone not specified by environment variable"
  echo UTC > /etc/container_environment/TZ
  sed -i "s#\;date\.timezone\ \=#date\.timezone\ \=\ UTC#g" /etc/php/7.2/cli/php.ini
  sed -i "s#\;date\.timezone\ \=#date\.timezone\ \=\ UTC#g" /etc/php/7.2/fpm/php.ini
fi
