FROM php:8.1-fpm-alpine
LABEL maintainer="David Goodwin <david@codepoets.co.uk> (@DavidGoodwin)"

# docker-entrypoint.sh dependencies
RUN apk add --no-cache \
		bash \
		su-exec

# Install required PHP extensions
RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		imap-dev \
		krb5-dev \
		postgresql-dev \
		sqlite-dev \
	; \
	docker-php-ext-configure \
		imap --with-imap-ssl --with-kerberos \
	; \
	docker-php-ext-install -j "$(nproc)" \
		imap \
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

ARG POSTFIXADMIN_VERSION=3.3.13
ARG POSTFIXADMIN_SHA512=bf7daaa089ee3adc4b557f1a7d0509d78979ef688fb725bab795f5c9d81e8774296245fde0cb184db51e9185cad381682c3ecc0bfadf852388b499a0a95cca64

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
