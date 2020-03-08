#!/bin/bash
set -eo pipefail

POSTFIXADMIN_DB_TYPE=${POSTFIXADMIN_DB_TYPE:=sqlite}
POSTFIXADMIN_DB_HOST=${POSTFIXADMIN_DB_HOST:=""}
POSTFIXADMIN_DB_USER=${POSTFIXADMIN_DB_USER:=""}
POSTFIXADMIN_DB_PASSWORD=${POSTFIXADMIN_DB_PASSWORD:=""}
POSTFIXADMIN_SMTP_SERVER=${POSTFIXADMIN_SMTP_SERVER:="localhost"}
POSTFIXADMIN_SMTP_PORT=${POSTFIXADMIN_SMTP_PORT:="25"}

# topsecret99
DEFAULT_SETUP_PASSWORD="791eb4ead7fd996c01bed30707ae27dd:b7910d09773104bf84c4f4951205d2198c7cfc4f"
POSTFIXADMIN_SETUP_PASSWORD=${POSTFIXADMIN_SETUP_PASSWORD:=$DEFAULT_SETUP_PASSWORD}


if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then

	if [ "${POSTFIXADMIN_SETUP_PASSWORD}" = "${DEFAULT_SETUP_PASSWORD}" ]; then
		echo >&2 "WARNING: Using default setup.php password of : topsecret99"
	fi

	if ! [ -e index.php -a -e scripts/postfixadmin-cli.php ]; then
		echo >&2 "Postfixadmin not found in $PWD - copying now..."
		if [ "$(ls -A)" ]; then
			echo >&2 "WARNING: $PWD is not empty - press Ctrl+C now if this is an error!"
			( set -x; ls -A; sleep 10 )
		fi
		tar cf - --one-file-system -C /usr/src/postfixadmin . | tar xf -
		echo >&2 "Complete! Postfixadmin has been successfully copied to $PWD"
	fi

	case "${POSTFIXADMIN_DB_TYPE}" in
		sqlite)
			;;
		mysqli)
			: "${POSTFIXADMIN_DB_PORT:=3306}"
			;;
		pgsql)
			: "${POSTFIXADMIN_DB_PORT:=5432}"
		;;
		*)
		echo >&2 "${POSTFIXADMIN_DB_TYPE} is not a supported value."
		exit 1
		;;
	esac

	if [ "${POSTFIXADMIN_DB_TYPE}" != "sqlite" ]; then
		if [ -z "${POSTFIXADMIN_DB_USER}" -o -z "${POSTFIXADMIN_DB_PASSWORD}" ]; then
			echo >&2 'Error: POSTFIXADMIN_DB_USER and POSTFIXADMIN_DB_PASSWORD must be specified. '
			exit 1
		fi
		timeout 15 bash -c "until echo > /dev/tcp/${POSTFIXADMIN_DB_HOST}/${POSTFIXADMIN_DB_PORT}; do sleep 0.5; done"
	fi

	if [ "${POSTFIXADMIN_DB_TYPE}" = 'sqlite' ]; then
		: "${POSTFIXADMIN_DB_NAME:=/var/tmp/postfixadmin.db}"

		if [ ! -f "${POSTFIXADMIN_DB_NAME}" ]; then
			echo "Creating sqlite db"
			touch $POSTFIXADMIN_DB_NAME
			chown www-data:www-data $POSTFIXADMIN_DB_NAME
			chmod 0700 $POSTFIXADMIN_DB_NAME
		fi
	fi

	if [ ! -e config.local.php ]; then
		touch config.local.php
		echo "Write config to $PWD/config.local.php"
		echo "<?php
		\$CONF['database_type'] = '${POSTFIXADMIN_DB_TYPE}';
		\$CONF['database_host'] = '${POSTFIXADMIN_DB_HOST}';
		\$CONF['database_port'] = '${POSTFIXADMIN_DB_PORT}';
		\$CONF['database_user'] = '${POSTFIXADMIN_DB_USER}';
		\$CONF['database_password'] = '${POSTFIXADMIN_DB_PASSWORD}';
		\$CONF['database_name'] = '${POSTFIXADMIN_DB_NAME}';
		\$CONF['setup_password'] = '${POSTFIXADMIN_SETUP_PASSWORD}';
		\$CONF['smtp_server'] = '${POSTFIXADMIN_SMTP_SERVER}';
		\$CONF['smtp_port'] = '${POSTFIXADMIN_SMTP_PORT}';
		\$CONF['configured'] = true;
		?>" | tee config.local.php
	else
		echo "WARNING: $PWD/config.local.php already exists."
		echo "Postfixadmin related environment variables have been ignored."
	fi

	if [ -f public/upgrade.php ]; then
		echo " ** Running database / environment upgrade.php "
		php public/upgrade.php
	fi
fi

exec "$@"
