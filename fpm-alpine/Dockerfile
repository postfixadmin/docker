FROM php:8.3-fpm-alpine
LABEL maintainer="David Goodwin <david@codepoets.co.uk> (@DavidGoodwin)"

# docker-entrypoint.sh dependencies
RUN apk add --no-cache \
		bash \
		su-exec

# Install required PHP extensions
RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		postgresql-dev \
		sqlite-dev \
	; \
	docker-php-ext-install -j "$(nproc)" \
		pdo_mysql \
		pdo_pgsql \
		pdo_sqlite \
		pgsql \
	; \
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .postfixadmin-phpexts-rundeps $runDeps; \
	apk del --no-network .build-deps

ARG POSTFIXADMIN_VERSION=4.0.1
ARG POSTFIXADMIN_SHA512=88be6834257580c7a52dce33ce552e1868a1b28ba639a3378a66278939640073af4f8893fbfac690e2df5e67db0143c5726aab575bf0e4014b39a03d46916831

ENV POSTFIXADMIN_VERSION $POSTFIXADMIN_VERSION
ENV POSTFIXADMIN_SHA512 $POSTFIXADMIN_SHA512

RUN set -eu; \
	curl -fsSL -o postfixadmin.tar.gz "https://github.com/postfixadmin/postfixadmin/archive/v${POSTFIXADMIN_VERSION}.tar.gz"; \
	echo "$POSTFIXADMIN_SHA512 *postfixadmin.tar.gz" | sha512sum -c -; \
	# upstream tarball include ./postfixadmin-postfixadmin-${POSTFIXADMIN_VERSION}/
	mkdir /usr/src/postfixadmin; \
	tar -xf postfixadmin.tar.gz -C /usr/src/postfixadmin --strip-components=1; \
	rm postfixadmin.tar.gz; \
	# Does not exist in tarball but is required
	mkdir -p /usr/src/postfixadmin/templates_c; \
	chown -R www-data:www-data /usr/src/postfixadmin

COPY docker-entrypoint.sh /usr/local/bin/

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

# https://github.com/moby/buildkit/issues/4503
# https://github.com/composer/composer/issues/11839
# https://github.com/composer/composer/blob/94fe2945456df51e122a492b8d14ac4b54c1d2ce/src/Composer/Console/Application.php#L217-L218
ENV COMPOSER_ALLOW_SUPERUSER 1

RUN set -eux; \
	export COMPOSER_HOME="$(mktemp -d)"; \
	# mysqli is expected but we use pdo
	composer install --ignore-platform-req=ext-mysqli --no-dev --no-interaction --working-dir /usr/src/postfixadmin; \
	# delete composer cache
	rm -rf "$COMPOSER_HOME"

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
