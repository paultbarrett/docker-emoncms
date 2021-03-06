#!/bin/bash 
#install emoncms
INDEX="/var/www/html/settings.php"
if [[ ! -d $INDEX ]]; then
  rm -rf /var/www/html
  git clone https://github.com/emoncms/emoncms.git /var/www/html
  git clone https://github.com/emoncms/event.git /var/www/html/Modules/event
  git clone https://github.com/emoncms/app.git /var/www/html/Modules/app
  git clone https://github.com/emoncms/usefulscripts.git /usr/local/bin/emoncms_usefulscripts
  git clone https://github.com/emoncms/dashboard.git /var/www/html/Modules/dashboard
  git clone https://github.com/emoncms/device.git /var/www/html/Modules/device
  cp /var/www/html/default.settings.php /var/www/html/settings.php
fi

chmod 644 /etc/mysql/my.cnf

touch /var/www/html/emoncms.log
chmod 666 /var/www/html/emoncms.log

# Check that user has supplied a MYSQL_PASSWORD
if [[ -z $MYSQL_PASSWORD ]]; then 
  # Uncomment the line below to use a random password
  #MYSQL_PASSWORD="$(pwgen -s 12 1)"
  echo 'Ensure that you have supplied a password using the -e MYSQL_PASSWORD="mypass"'
  exit 1;
fi

# Initialize MySQL if it not initialized yet
MYSQL_HOME="/var/lib/mysql"
if [[ ! -d $MYSQL_HOME/mysql ]]; then
  echo "=> Installing MySQL ..."
  chmod -R 777 /var/lib/mysql
  mysql_install_db # > /dev/null 2>&1
else
  echo "=> Using an existing volume of MySQL"
fi

# Run db scripts only if there's no existing emoncms database
EMON_HOME="/var/lib/mysql/emoncms"
if [[ ! -d $EMON_HOME ]]; then

    # Start MySQL Server
    service mysql start > /dev/null 2>&1

    sleep 10

    # Initialize the db and create the user 
    echo "CREATE DATABASE emoncms;" >> init.sql
    echo "CREATE USER 'emoncms'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" >> init.sql
    echo "GRANT ALL ON emoncms.* TO 'emoncms'@'localhost';" >> init.sql
    echo "flush privileges;" >> init.sql
    mysql < init.sql

    # Cleanup
    rm init.sql

    # Stop MySQL Server
    sleep 10
    service mysql stop > /dev/null 2>&1
    
fi

# Update the settings file for emoncms
EMON_DIR="/var/www/html"
SETPHP="$EMON_DIR/settings.php"
if [[ ! -d $SETPHP ]]; then
  cp "$EMON_DIR/default.settings.php" "$EMON_DIR/settings.php"
  sed -i "s/_DB_USER_/emoncms/" "$EMON_DIR/settings.php"
  sed -i "s/_DB_PASSWORD_/$MYSQL_PASSWORD/" "$EMON_DIR/settings.php"
  sed -i "s/localhost/127.0.0.1/" "$EMON_DIR/settings.php"
fi

echo "==========================================================="
echo "The username and password for the emoncms user is:"
echo ""
echo "   username: emoncms"
echo "   password: $MYSQL_PASSWORD"
echo ""
echo "==========================================================="

# Setup Apache
source /etc/apache2/envvars

# Use supervisord to start all processes
supervisord -c /etc/supervisor/conf.d/supervisord.conf
