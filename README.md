# Building

`docker build --pull --rm -t postfixadmin-image variant`

## Image Variants

The following variant are currently provided:

### apache

This starts an Apache webserver with PHP, so you can use `postfixadmin` out of the box.

### fpm-alpine

This image has a very small footprint. It is based on Alpine Linux and starts only a PHP FPM process. Use this variant if you already have a seperate webserver. If you need more tools, that are not available on Alpine Linux, use the `fpm` image instead.

### fpm

This image starts only a PHP FPM container. Use this variant if you already have a seperate webserver.

# Running

## No config.local.php / no existing setup

If you do not have a config.local.php, then we fall back to look for environment variables to generate one.

POSTFIXADMIN\_DB\_TYPE can be one of :

 * mysqli
 * pgsql
 * sqlite

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

Note: An sqlite database is used as a fallback if you do not have a config.local.php and do not specify the above variables.


## Existing config.local.php

```bash
docker run --name postfixadmin -p 8080:80 postfixadmin-image
```

# Docker Compose

Try something like the below; changing the usernames/passwords as required.


```
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

