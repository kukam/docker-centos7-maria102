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

# Directory already exists and has content (other thab '.' and '..')
if [ -d "${DATADIR}/mysql" ] && [ "$( ls -A "${DATADIR}/mysql" )" ]; then
	echo "info Found existing data directory. MySQL already setup."
else
	echo "info No existing MySQL data directory found. Setting up MySQL for the first time."

	# Create datadir if not exist yet
	if [ ! -d "${DATADIR}" ]; then
		echo "info" "Creating empty data directory in: ${DATADIR}."
		mkdir -p ${DATADIR}
		chown -R mysql:mysql ${DATADIR}
	fi

	# Install Database
	mysql_install_db --datadir=${DATADIR} --user=mysql > /dev/null

	# Start server
	mysqld --user=mysql --skip-networking &

	# Wait at max 60 seconds for it to start up
	i=0
	max=60
	while [ $i -lt $max ]; do
		if echo 'SELECT 1' |  mysql --protocol=socket -uroot > /dev/null 2>&1; then
			break
		fi
		echo "info Initializing ..."
		sleep 1s
		i=$(( i + 1 ))
	done

	# Get current pid
	pid="$(pgrep mysqld | head -1)"
	if [ "${pid}" = "" ]; then
		echo "err Could not find running MySQL PID."
		echo "err MySQL init process failed."
		exit 1
	fi

	# create temp file
	tfile=`mktemp`
	if [ ! -f "$tfile" ]; then
	    return 1
	fi

	# Bootstrap MySQL
	echo "USE mysql;" >> $tfile
	echo "FLUSH PRIVILEGES;" >> $tfile
	echo "DELETE FROM mysql.user;" >> $tfile
	echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$DB_ADMIN_PASSWORD' WITH GRANT OPTION;" >> $tfile
	echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$DB_ADMIN_PASSWORD' WITH GRANT OPTION;" >> $tfile
	echo "DROP DATABASE IF EXISTS test ;" >> $tfile

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
	cat $tfile | mysql --protocol=socket -uroot > /dev/null 2>&1
	rm $tfile

	# Shutdown MySQL
	kill -s TERM ${pid}
	i=0
	max=60
	while [ $i -lt $max ]; do
		if ! pgrep mysqld >/dev/null 2>&1; then
			break
		fi
		sleep 1s
		i=$(( i + 1 ))
	done

	# Check if it is still running
	if pgrep mysqld >/dev/null 2>&1; then
		echo "err Unable to shutdown MySQL server."
		echo "err MySQL init process failed."
		exit 1
	fi
	echo "info MySQL successfully installed."

fi

###
### Start
###
echo "info Starting $(mysqld --version)"
exec "$@"
