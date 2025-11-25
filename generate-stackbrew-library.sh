#!/usr/bin/env bash
set -Eeuo pipefail

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
defaultVariant='apache'

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		files="$(
			git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						if ($i ~ /^--from=/) {
							next
						}
						print $i
					}
				}
			'
		)"
		fileCommit Dockerfile $files
	)
}

gawkParents='
	{ cmd = toupper($1) }
	cmd == "FROM" {
		print $2
		next
	}
	cmd == "COPY" {
		for (i = 2; i < NF; i++) {
			if ($i ~ /^--from=/) {
				gsub(/^--from=/, "", $i)
				print $i
				next
			}
		}
	}
'

getArches() {
	local repo="$1"; shift
	local officialImagesBase="${BASHBREW_LIBRARY:-https://github.com/docker-library/official-images/raw/HEAD/library}/"

	local parentRepoToArchesStr
	parentRepoToArchesStr="$(
		find -name 'Dockerfile' -exec gawk "$gawkParents" '{}' + \
			| sort -u \
			| gawk -v officialImagesBase="$officialImagesBase" '
				$1 !~ /^('"$repo"'|scratch|.*\/.*)(:|$)/ {
					printf "%s%s\n", officialImagesBase, $1
				}
			' \
			| xargs -r bashbrew cat --format '["{{ .RepoName }}:{{ .TagName }}"]="{{ join " " .TagEntry.Architectures }}"'
	)"
	eval "declare -g -A parentRepoToArches=( $parentRepoToArchesStr )"
}
getArches 'postfixadmin'

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

latest="$(curl -fsSL https://api.github.com/repos/postfixadmin/postfixadmin/releases/latest | jq -r '.tag_name' | tr -d 'v')"

variants=( */ )
variants=( "${variants[@]%/}" )

for variant in "${variants[@]}"; do
	commit="$(dirCommit "$variant")"
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

	variantParents="$(gawk "$gawkParents" "$variant/Dockerfile")"
	variantArches=
	for variantParent in $variantParents; do
		parentArches="${parentRepoToArches[$variantParent]:-}"
		if [ -z "$parentArches" ]; then
			continue
		elif [ -z "$variantArches" ]; then
			variantArches="$parentArches"
		else
			variantArches="$(
				comm -12 \
					<(xargs -n1 <<<"$variantArches" | sort -u) \
					<(xargs -n1 <<<"$parentArches" | sort -u)
				)"
		fi
	done

	cat <<-EOE

		Tags: $(join ', ' "${variantAliases[@]}")
		Architectures: $(join ', ' $variantArches)
		Directory: $variant
		GitCommit: $commit
	EOE
done
