#!/bin/bash
set -euo pipefail

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
defaultVariant='apache'

# Get the most recent commit which modified any of "$@".
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# Get the most recent commit which modified "$1/Dockerfile" or any file that
# the Dockerfile copies into the rootfs (with COPY).
dockerfileCommit() {
	local dir="$1"; shift
	(
		cd "$dir";
		fileCommit Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++)
							print $i;
				}
			')
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

	eval "declare -g -A parentRepoToArches=( $(
		find -name 'Dockerfile' -exec awk '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|microsoft\/[^:]+)(:|$)/ {
					print "'"$officialImagesUrl"'" $2
				}
			' '{}' + \
			| sort -u \
			| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
	) )"
}
getArches 'postfixadmin'

# Header.
cat <<-EOH
# This file is generated via https://github.com/postfixadmin/docker/blob/$(fileCommit "$self")/$self
Maintainers: David Goodwin <david@codepoets.co.uk> (@DavidGoodwin)
GitRepo: https://github.com/postfixadmin/docker.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

SEARCHFOR="Upgrade available - the latest version is "
latest=$(curl -fsSL http://postfixadmin.sourceforge.net/update-check.php | grep -iF "$SEARCHFOR" | sed -E "s@${SEARCHFOR}([0-9.]+)</div>@\1@")

variants=( */ )
variants=( "${variants[@]%/}" )

for variant in "${variants[@]}"; do
	commit="$(dockerfileCommit "$variant")"
	fullversion="$(git show "$commit":"$variant/Dockerfile" | grep -iF "ARG POSTFIXADMIN_VERSION" | sed -E "s@ARG POSTFIXADMIN_VERSION=([0-9.]+)@\1@")"

	versionAliases=( "$fullversion" "${fullversion%.*}" "${fullversion%.*.*}" )
	if [ "$fullversion" = "$latest" ]; then
		versionAliases+=( "latest" )
	fi

	variantAliases=( "${versionAliases[@]/%/-$variant}" )
	variantAliases=( "${variantAliases[@]//latest-}" )

	if [ "$variant" = "$defaultVariant" ]; then
		variantAliases+=( "${versionAliases[@]}" )
	fi

	variantParent="$(awk 'toupper($1) == "FROM" { print $2 }' "$variant/Dockerfile")"
	variantArches="${parentRepoToArches[$variantParent]}"

	cat <<-EOE

		Tags: $(join ', ' "${variantAliases[@]}")
		Architectures: $(join ', ' $variantArches)
		Directory: $variant
		GitCommit: $commit
	EOE
done
