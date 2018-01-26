#!/bin/bash
set -euo pipefail

for variant in apache fpm fpm-alpine; do
	dir="$variant"
	mkdir -p "$dir"
	cp -a "docker-entrypoint.sh" "$dir/docker-entrypoint.sh"
	travisEnv+='\n  - VARIANT='"$dir"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
