FROM php:7.3-fpm
LABEL maintainer="David Goodwin <david@codepoets.co.uk> (@DavidGoodwin)"

# Install required PHP extensions
RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
	libpq-dev \
	libsqlite3-dev \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		mysqli \
		pdo_mysql \
		pdo_pgsql \
		pdo_sqlite \
		pgsql \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
		ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
		\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

ARG POSTFIXADMIN_VERSION=3.2.3
ARG POSTFIXADMIN_SHA512=d44addb9a3ca830caf55b603363054df561d659957f21cab7523465ebf02ca18abe7fcf298fe718d957d0b7bf5613e2dde69c78c26e0f7f6f595d79b28fe08ab

ENV POSTFIXADMIN_VERSION $POSTFIXADMIN_VERSION
ENV POSTFIXADMIN_SHA512 $POSTFIXADMIN_SHA512


RUN set -eu; \
	curl -fsSL -o postfixadmin.tar.gz "https://github.com/postfixadmin/postfixadmin/archive/postfixadmin-${POSTFIXADMIN_VERSION}.tar.gz"; \
	echo "$POSTFIXADMIN_SHA512 *postfixadmin.tar.gz" | sha512sum -c -; \
	# upstream tarball include ./postfixadmin-postfixadmin-${POSTFIXADMIN_VERSION}/
	mkdir /usr/src/postfixadmin; \
	tar -xf postfixadmin.tar.gz -C /usr/src/postfixadmin --strip-components=1; \
	rm postfixadmin.tar.gz; \
	# Does not exist in tarball but is required
	mkdir -p /usr/src/postfixadmin/templates_c; \
	chown -R www-data:www-data /usr/src/postfixadmin

COPY docker-entrypoint.sh /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]
