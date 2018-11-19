#!/bin/bash
set -euo pipefail

declare -A cmd=(
	[apache]='apache2-foreground'
	[fpm]='php-fpm'
	[fpm-alpine]='php-fpm'
)

declare -A base=(
	[apache]='debian'
	[fpm]='debian'
	[fpm-alpine]='alpine'
)

for variant in apache fpm fpm-alpine; do
	dir="$variant"
	template="Dockerfile-${base[$variant]}.template"
	mkdir -p "$dir"
	cp -a "docker-entrypoint.sh" "$dir/docker-entrypoint.sh"
	sed -r \
		-e 's!%%VARIANT%%!'"$variant"'!g' \
		-e 's!%%CMD%%!'"${cmd[$variant]}"'!g' \
		"Dockerfile-${base[$variant]}.template" > "$dir/Dockerfile"
	if [ $variant != "apache" ]; then
		sed -i -e '/APACHE_DOCUMENT_ROOT/d' "$dir/Dockerfile"
	fi
	travisEnv+='\n  - VARIANT='"$dir"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
