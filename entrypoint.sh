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
	log "info" "Found existing data directory. MySQL already setup."
else
	log "info" "No existing MySQL data directory found. Setting up MySQL for the first time."

	# Create datadir if not exist yet
	if [ ! -d "${DATADIR}" ]; then
		log "info" "Creating empty data directory in: ${DATADIR}."
		run "mkdir -p ${DATADIR}"
		run "chown -R mysql:mysql "${DATADIR}"
	fi

	# Install Database
	run "mysql_install_db --datadir=${DATADIR} --user=mysql > /dev/null"

	# Start server
	run "mysqld --skip-networking &"

	# Wait at max 60 seconds for it to start up
	i=0
	max=60
	while [ $i -lt $max ]; do
		if echo 'SELECT 1' |  mysql --protocol=socket -uroot  > /dev/null 2>&1; then
			break
		fi
		log "info" "Initializing ..."
		sleep 1s
		i=$(( i + 1 ))
	done

	# Get current pid
	pid="$(pgrep mysqld | head -1)"
	if [ "${pid}" = "" ]; then
		log "err" "Could not find running MySQL PID."
		log "err" "MySQL init process failed."
		exit 1
	fi

	# Bootstrap MySQL
	echo "FLUSH PRIVILEGES;" | mysql --protocol=socket -uroot
	echo "DELETE FROM mysql.user;" | mysql --protocol=socket -uroot
	echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$DB_ADMIN_PASSWORD' WITH GRANT OPTION;" | mysql --protocol=socket -uroot
	echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$DB_ADMIN_PASSWORD' WITH GRANT OPTION;" | mysql --protocol=socket -uroot
	echo "DROP DATABASE IF EXISTS test ;" | mysql --protocol=socket -uroot
	
	# Create new database
	if [ "$DB_NAME" != "" ]; then
		echo "[i] Creating database: $DB_NAME"
		echo "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci;" | mysql --protocol=socket -uroot

		# set new User and Password
		if [ "$DB_USER" != "" ] && [ "$DB_USER_PASSWORD" != "" ]; then
		echo "[i] Creating user: $DB_USER with password $DB_USER_PASSWORD"
		echo "GRANT ALL ON \`$DB_NAME\`.* to '$DB_USER'@'%' IDENTIFIED BY '$DB_USER_PASSWORD';" | mysql --protocol=socket -uroot
		fi
	fi

	echo "FLUSH PRIVILEGES ;" | mysql --protocol=socket -uroot

	# Shutdown MySQL
	log "info" "Shutting down MySQL."
	run "kill -s TERM ${pid}"
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
		log "err" "Unable to shutdown MySQL server."
		log "err" "MySQL init process failed."
		exit 1
	fi
	log "info" "MySQL successfully installed."
fi

###
### Start
###
log "info" "Starting $(mysqld --version)"
exec "$@"
