#!/bin/bash
set -euo pipefail

PHPVERSION="8.3"
POSTFIXADMIN_VERSION=4.0.5
POSTFIXADMIN_SHA512=b9549137e5bb6cf69fe76aef2711092a7e74ec223ee272d0303430b03da16ba8cfe704047f8e07ee5bd1ef6b632cac9ae2c0830271629b193c395197e1f4d93d

declare -A cmd=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
	[frankenphp]='frankenphp", "run", "--config", "/etc/caddy/Caddyfile'
)

declare -A base=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
	[frankenphp]='frankenphp'
)

for variant in apache fpm fpm-alpine frankenphp; do
	dir="$variant"
	template="Dockerfile-${base[$variant]}.template"
	mkdir -p "$dir"
	cp -a "docker-entrypoint.sh" "$dir/docker-entrypoint.sh"
	sed -r \
		-e 's!%%VARIANT%%!'"$variant"'!g' \
		-e 's!%%PHPVERSION%%!'"${PHPVERSION}"'!g' \
		-e 's!%%POSTFIXADMIN_VERSION%%!'"${POSTFIXADMIN_VERSION}"'!g' \
		-e 's!%%POSTFIXADMIN_SHA512%%!'"${POSTFIXADMIN_SHA512}"'!g' \
		-e 's!%%CMD%%!'"${cmd[$variant]}"'!g' \
		"Dockerfile-${base[$variant]}.template" > "$dir/Dockerfile"
	if [ $variant != "apache" ]; then
		sed -i -e '/APACHE_DOCUMENT_ROOT/d' "$dir/Dockerfile"
	fi
	sed -i -e 's/gosu/su-exec/g' "fpm-alpine/docker-entrypoint.sh"
done
