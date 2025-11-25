FROM php:8.3-apache
LABEL maintainer="David Goodwin <david@codepoets.co.uk> (@DavidGoodwin)"

# docker-entrypoint.sh dependencies
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		gosu \
	; \
	rm -rf /var/lib/apt/lists/*

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
	docker-php-ext-install -j "$(nproc)" \
		pdo_mysql \
		pdo_pgsql \
		pdo_sqlite \
		pgsql \
	; \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); print so }' \
		| sort -u \
		| xargs -rt dpkg-query --search \
# https://manpages.debian.org/trixie/dpkg/dpkg-query.1.en.html#S (we ignore diversions and it'll be really unusual for more than one package to provide any given .so file)
		| awk 'sub(":$", "", $1) { print $1 }' \
		| sort -u \
		| xargs -rt apt-mark manual; \
		\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	apt-get dist-clean

ARG POSTFIXADMIN_VERSION=4.0.1
ARG POSTFIXADMIN_SHA512=88be6834257580c7a52dce33ce552e1868a1b28ba639a3378a66278939640073af4f8893fbfac690e2df5e67db0143c5726aab575bf0e4014b39a03d46916831

ENV POSTFIXADMIN_VERSION $POSTFIXADMIN_VERSION
ENV POSTFIXADMIN_SHA512 $POSTFIXADMIN_SHA512
ENV APACHE_DOCUMENT_ROOT /var/www/html/public

RUN set -eu; sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf; \
	sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

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
	composerDeps=" \
		unzip \
	"; \
	apt-get update; \
	apt-get install -y --no-install-recommends $composerDeps; \
	\
	export COMPOSER_HOME="$(mktemp -d)"; \
	# mysqli is expected but we use pdo
	composer install --ignore-platform-req=ext-mysqli --no-dev --no-interaction --working-dir /usr/src/postfixadmin; \
	# delete composer cache
	rm -rf "$COMPOSER_HOME"; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $composerDeps; \
	apt-get dist-clean

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]
