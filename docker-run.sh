#!/bin/bash

r=1
while [ $r -ne 0 ]; do
  mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST -e "status" > /dev/null 2>&1
  r=$?
  if [ $r -ne 0 ]; then
    echo "Waiting that SQL database is up..."
    sleep 2
  fi
done

mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME -e "SELECT * FROM llx_const" > /dev/null 2>&1
if [ $? -ne 0 ]; then

	echo "Importing tables SQL ..."
	for f in /var/www/html/install/mysql/tables/*.sql; do
		if [[ $f != *.key.sql ]]; then
			mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME < $f > /dev/null 2>&1
		fi
	done

	echo "Importing tables key SQL ..."
	for f in /var/www/html/install/mysql/tables/*.key.sql; do
		mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME < $f > /dev/null 2>&1
	done

	echo "Importing functions SQL ..."
	for f in /var/www/html/install/mysql/functions/*.sql; do
		mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME < $f > /dev/null 2>&1
	done

	echo "Importing data SQL ..."
	for f in /var/www/html/install/mysql/data/*.sql; do
		mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME < $f > /dev/null 2>&1
	done

	echo "Create SuperAdmin account ..."
	pass_crypted=`echo -n $DOLI_ADMON_PASSWORD | md5sum | awk '{print $1}'`
	mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME -e "INSERT INTO llx_user (entity, login, pass_crypted, lastname, admin, statut) VALUES (0, '${DOLI_ADMIN_LOGIN}', '${pass_crypted}', 'SuperAdmin', 1, 1);" > /dev/null 2>&1

	echo "Set some default const ..."
	mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME -e "DELETE FROM llx_const WHERE name='MAIN_VERSION_LAST_INSTALL';" > /dev/null 2>&1
	mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME -e "DELETE FROM llx_const WHERE name='MAIN_NOT_INSTALLED';" > /dev/null 2>&1
	mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME -e "DELETE FROM llx_const WHERE name='MAIN_LANG_DEFAULT';" > /dev/null 2>&1
	mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME -e "INSERT INTO llx_const(name,value,type,visible,note,entity) values('MAIN_VERSION_LAST_INSTALL', '${DOLI_VERSION}', 'chaine', 0, 'Dolibarr version when install', 0);" > /dev/null 2>&1
	mysql -u $DOLI_DB_USER -p${DOLI_DB_PASSWORD} -h $DOLI_DB_HOST $DOLI_DB_NAME -e "INSERT INTO llx_const(name,value,type,visible,note,entity) VALUES ('MAIN_LANG_DEFAULT', 'auto', 'chaine', 0, 'Default language', 1);" > /dev/null 2>&1

	echo "Create conf file ..."
	cat <<EOF > /var/www/html/conf/conf.php
<?php
\$dolibarr_main_url_root='${DOLI_URL_ROOT}';
\$dolibarr_main_document_root='/var/www/html';
\$dolibarr_main_url_root_alt='/custom';
\$dolibarr_main_document_root_alt='/var/www/html/custom';
\$dolibarr_main_data_root='/var/www/documents';
\$dolibarr_main_db_host='${DOLI_DB_HOST}';
\$dolibarr_main_db_port='3306';
\$dolibarr_main_db_name='${DOLI_DB_NAME}';
\$dolibarr_main_db_prefix='llx_';
\$dolibarr_main_db_user='${DOLI_DB_USER}';
\$dolibarr_main_db_pass='${DOLI_DB_PASSWORD}';
\$dolibarr_main_db_type='mysqli';
EOF

	touch /var/www/documents/install.lock
	chown www-data:www-data /var/www/html/conf/conf.php && chmod 400 /var/www/html/conf/conf.php
	chmod 400 /var/www/documents/install.lock

	cat <<EOF > /usr/local/etc/php/php.ini
date.timezone = $PHP_INI_DATE_TIMEZONE
EOF

fi

exec apache2-foreground
