#!/usr/bin/env bash
set -eo pipefail

# usage: get_env_value VAR [DEFAULT]
#    ie: get_env_value 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
function get_env_value() {
	local varName="${1}"
	local fileVarName="${varName}_FILE"
	local defaultValue="${2:-}"

	if [ "${!varName:-}" ] && [ "${!fileVarName:-}" ]; then
		echo >&2 "error: both ${varName} and ${fileVarName} are set (but are exclusive)"
		exit 1
	fi

	local value="${defaultValue}"
	if [ "${!varName:-}" ]; then
	  value="${!varName}"
	elif [ "${!fileVarName:-}" ]; then
		value="$(< "${!fileVarName}")"
	fi

	echo "${value}"
	exit 0
}

function get_database_env_value() {
	local suffix="$1"
	local default_value="${2-}"

	local primary_name="POSTFIXADMIN_DB_${suffix}"
	local fallback_name="POSTFIXADMIN_DATABASE_${suffix}"

	local primary_file_name="${primary_name}_FILE"
	local fallback_file_name="${fallback_name}_FILE"

	if [[ -n "${!primary_name:-}" && -n "${!fallback_name:-}" ]]; then
		echo >&2 "Error : both ${primary_name} and ${fallback_name} are set (but are exclusive)"
		exit 1
	fi

	if [[ -n "${!primary_file_name:-}" && -n "${!fallback_file_name:-}" ]]; then
		echo >&2 "Error : both ${primary_file_name} and ${fallback_file_name} are set (but are exclusive)"
		exit 1
	fi

	# Priority to POSTFIXADMIN_DB_*
	if [[ -n "${!primary_name:-}" || -n "${!primary_file_name:-}" ]]; then
		get_env_value "${primary_name}" "${default_value}"
	else
		get_env_value "${fallback_name}" "${default_value}"
	fi
}

function php_escape() {
    local value="$1"

    value=${value//\\/\\\\}
    value=${value//\'/\\\'}

    printf '%s' "${value}"
}

function config_name_from_env() {
    local env_name="$1"

    case "${env_name}" in
        POSTFIXADMIN_DB_TYPE)
            printf '%s' 'database_type'
            ;;
        POSTFIXADMIN_DB_HOST)
            printf '%s' 'database_host'
            ;;
        POSTFIXADMIN_DB_PORT)
            printf '%s' 'database_port'
            ;;
        POSTFIXADMIN_DB_USER)
            printf '%s' 'database_user'
            ;;
        POSTFIXADMIN_DB_PASSWORD)
            printf '%s' 'database_password'
            ;;
        POSTFIXADMIN_DB_NAME)
            printf '%s' 'database_name'
            ;;
        *)
            local config_name="${env_name#POSTFIXADMIN_}"
            printf '%s' "${config_name,,}"
            ;;
    esac
}

# Init vars for running script
export POSTFIXADMIN_DB_TYPE=$(get_database_env_value 'TYPE' 'sqlite')
export POSTFIXADMIN_DB_HOST=$(get_database_env_value "HOST" "")
export POSTFIXADMIN_DB_NAME=$(get_database_env_value "NAME" "")
export POSTFIXADMIN_DB_PORT=$(get_database_env_value "PORT" "")
export POSTFIXADMIN_DB_USER=$(get_database_env_value "USER" "")
export POSTFIXADMIN_DB_PASSWORD=$(get_database_env_value "PASSWORD" "")

DEFAULT_SETUP_PASSWORD="changeme"
export POSTFIXADMIN_SETUP_PASSWORD=$(get_env_value "POSTFIXADMIN_SETUP_PASSWORD" "${DEFAULT_SETUP_PASSWORD}")

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then

	if [ "${POSTFIXADMIN_SETUP_PASSWORD}" = "${DEFAULT_SETUP_PASSWORD}" ]; then
		echo >&2 "WARNING: setup.php password not set"
	fi

	if ! [ -e index.php ] && ! [ -e scripts/postfixadmin-cli.php ]; then
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

	if [ "${POSTFIXADMIN_DB_TYPE}" = 'sqlite' ]; then
		: "${POSTFIXADMIN_DB_NAME:=/var/tmp/postfixadmin.db}"

		if [ ! -f "${POSTFIXADMIN_DB_NAME}" ]; then
			echo "Creating sqlite db"
			touch $POSTFIXADMIN_DB_NAME
			chown www-data:www-data $POSTFIXADMIN_DB_NAME
			chmod 0700 $POSTFIXADMIN_DB_NAME
		fi
	else
		if [ -z "${POSTFIXADMIN_DB_USER}" ] || [ -z "${POSTFIXADMIN_DB_PASSWORD}" ]; then
			echo >&2 'Error: POSTFIXADMIN_DB_USER and POSTFIXADMIN_DB_PASSWORD must be specified. '
			exit 1
		fi
		timeout 15 bash -c "until echo > /dev/tcp/${POSTFIXADMIN_DB_HOST}/${POSTFIXADMIN_DB_PORT}; do sleep 0.5; done"
	fi

	if [ ! -e config.local.php ]; then
		touch config.local.php
		echo "Write config to $PWD/config.local.php"
		{
			printf '%s\n' '<?php'
			printf '%s\n' ''
			printf '%s\n' '// Generated automatically by Docker entrypoint.'
			printf '%s\n' ''
			printf "%s\n" "\$CONF['configured'] = true;"

			while IFS= read -r env_name; do
				case "${env_name}" in
					POSTFIXADMIN_CONFIG_FILE \
					| POSTFIXADMIN_CONFIGURED \
					| POSTFIXADMIN_DATABASE_* \
					| POSTFIXADMIN_*_FILE)
						continue
						;;
				esac

				config_name="$(config_name_from_env "${env_name}")"
				value="${!env_name}"

				printf "\$CONF['%s'] = '%s';\n" \
					"${config_name}" \
					"$(php_escape "${value}")"

			done < <(
				compgen -e |
					grep '^POSTFIXADMIN_' |
					sort
			)

			printf '\n'
		} >"$PWD/config.local.php"
		cat "$PWD/config.local.php"
	else
		echo "WARNING: $PWD/config.local.php already exists."
		echo "Postfixadmin related environment variables have been ignored."
	fi

	if [ -f public/upgrade.php ]; then
		echo " ** Running database / environment upgrade.php "
		gosu www-data php public/upgrade.php
	fi
fi

exec "$@"
