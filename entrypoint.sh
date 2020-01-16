#!/bin/sh

# parameters
: ${DB_NAME:-"db1"}
: ${DB_USER:-"admin"}
: ${DB_USER_PASSWORD:-"admin"}
: ${DB_ADMIN_PASSWORD:-"mysql"}

if [ ! -d "/run/mysqld" ]; then
	mkdir -p /run/mysqld
	chown -R mysql:mysql /run/mysqld
fi

if [ ! -z "$(ls -A "${DATADIR}")" ]; then
	echo '[i] MySQL directory already present, skipping creation'
else
	echo "[i] MySQL data directory not found, creating initial DBs"

	chown -R mysql:mysql "${DATADIR}"

	# init database
	echo "Initializing database"
	mysql_install_db --user=mysql --datadir=${DATADIR} > /dev/null
	echo 'Database initialized'

	echo "[i] MySql root password: $DB_ADMIN_PASSWORD"

	# create temp file
	tfile=`mktemp`
	if [ ! -f "$tfile" ]; then
	    return 1
	fi

	# save sql
	echo "[i] Create temp file: $tfile"
	echo "USE mysql;" >> $tfile
	echo "FLUSH PRIVILEGES;" >> $tfile
	echo "DELETE FROM mysql.user;" >> $tfile
	echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$DB_ADMIN_PASSWORD' WITH GRANT OPTION;" >> $tfile
	echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$DB_ADMIN_PASSWORD' WITH GRANT OPTION;" >> $tfile

	# Create new database
	if [ "$DB_NAME" != "" ]; then
		echo "[i] Creating database: $DB_NAME"
		echo "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile

		# set new User and Password
		if [ "$DB_USER" != "" ] && [ "$DB_USER_PASSWORD" != "" ]; then
		echo "[i] Creating user: $DB_USER with password $DB_USER_PASSWORD"
		echo "GRANT ALL ON \`$DB_NAME\`.* to '$DB_USER'@'%' IDENTIFIED BY '$DB_USER_PASSWORD';" >> $tfile
		fi
	fi

	echo 'FLUSH PRIVILEGES;' >> $tfile

	# run sql in tempfile
	echo "[i] run tempfile: $tfile"
	/usr/sbin/mysqld --user=mysql --datadir=${DATADIR} --bootstrap --verbose=0 < $tfile
	rm -f $tfile
fi

exec "$@"
