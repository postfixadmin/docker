[![Build Status](https://travis-ci.org/postfixadmin/docker.svg?branch=master)](https://travis-ci.org/postfixadmin/docker)

# Building

 * Clone this repo ( `git clone https://github.com/postfixadmin/docker.git docker` ) and then run :
 * `docker build --pull --rm -t postfixadmin-image variant` from within the created directory.

## Image Variants

The following variant are currently provided:

### apache

This starts an Apache webserver with PHP, so you can use `postfixadmin` out of the box.

### fpm-alpine

This image has a very small footprint. It is based on Alpine Linux and starts only a PHP FPM process. Use this variant if you already have a seperate webserver. 

If you need more tools, that are not available on Alpine Linux, use the `fpm` image instead.

### fpm

This image is based on Debian and starts only a PHP FPM container. 

Use this variant if you already have a seperate webserver.

# Running

## No config.local.php / no existing setup

If you do not have a config.local.php, then we fall back to look for environment variables to generate one.

POSTFIXADMIN\_DB\_TYPE can be one of :

 * mysqli
 * pgsql
 * sqlite

If you're using sqlite, you can omit the POSTFIXADMIN\_DB\_HOST, ...USER, ...PASSWORD variables. POSTFIXADMin_DB_NAME needs to point to an appropriate file path, which is created if it does not already exist.

You'll probably want to use a volume so you can persist any SQLite database beyond a single container's life. 

```bash
docker run -e POSTFIXADMIN_DB_TYPE=mysqli \
           -e POSTFIXADMIN_DB_HOST=whatever \
           -e POSTFIXADMIN_DB_USER=user \
           -e POSTFIXADMIN_DB_PASSWORD=topsecret \
           -e POSTFIXADMIN_DB_NAME=postfixadmin \
           --name postfixadmin \
           -p 8080:80 \
        postfixadmin-image
```

Note: An SQLite database is not recommend but used as a fallback if you do not have a config.local.php or do not specify the above variables.

## Existing config.local.php

```bash
docker run --name postfixadmin -v /local/path/to/config.local.php:/var/www/html/config.local.php -p 8080:80 postfixadmin-image
```

# Docker Compose

Try something like the below in a **docker-compose.yml** file; changing the usernames/passwords as required.

Then run : `docker-compose up`

```yaml
version: '3'

services:
   db:
     image: mysql:5.7
     restart: always
     environment:
       MYSQL_ROOT_PASSWORD: notSecureChangeMe
       MYSQL_DATABASE: postfixadmin
       MYSQL_USER: postfixadmin
       MYSQL_PASSWORD: postfixadminPassword

   postfixadmin:
     depends_on:
       - db
     image: postfixadmin-image:latest
     ports:
       - "8000:80"
     restart: always
     environment:
       POSTFIXADMIN_DB_TYPE: mysqli
       POSTFIXADMIN_DB_HOST: db
       POSTFIXADMIN_DB_USER: postfixadmin
       POSTFIXADMIN_DB_NAME: postfixadmin
       POSTFIXADMIN_DB_PASSWORD: postfixadminPassword
```

