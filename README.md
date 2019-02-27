[![Build Status](https://travis-ci.org/postfixadmin/docker.svg?branch=master)](https://travis-ci.org/postfixadmin/docker)

# Building

 * Clone this repo ( `git clone https://github.com/postfixadmin/docker.git docker` ) and then run :
 * `docker build --pull --rm -t postfixadmin-image <VARIANT>` from within the created directory (where \<VARIANT\> is replaced by apache, fpm or fpm-alpine)

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

Some knowledge of Postixadmin is assumed. 

Advanced users will probably want to specify a custom configuration (config.local.php file).

If you're just trying out the software, there's probably no need for a config.local.php file.


## No config.local.php / no existing setup

You have two options :

 * Use a default sqlite database, or
 * Use an external database (MySQL, PgSQL etc).
 
You can configure this through the following environment variables when running the docker container.

 * POSTFIXADMIN\_DB\_TYPE=...  - sqlite, mysqli, pgsql
 * POSTFIXADMIN\_DB\_NAME=.... - database name or path to database file (sqlite)
 * POSTFIXADMIN\_DB\_USER=...  - mysqli/pgsql only (db server user name)
 * POSTFIXADMIN\_DB\_PASSWORD=... - mysqli/pgsql only (db server user password)
 * POSTFIXADMIN\_SETUP\_PASSWORD=... - generated from setup.php, default is topsecret99

Note: An SQLite database is probably not recommended for production use, but is a quick and easy way to try out the software without dependencies. 

### Example docker run

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


## Existing setup / with config.local.php

Postfixadmin's default configuration is stored in a config.inc.php file (see https://github.com/postfixadmin/postfixadmin/blob/master/config.inc.php ). 

To customise, copy this file, remove everything you don't want to override, and call it **config.local.php**.


```bash
docker run -v /local/path/to/config.local.php:/var/www/html/config.local.php \
           --name postfixadmin \
           -p 8080:80 \
           postfixadmin-image
```

# Next Steps

Once the container is running, try visiting :

 * http://localhost:8080/setup.php (to create admin users, default setup password is `topsecret99`)
 * http://localhost:8080/ (to login as the domain admin you created through setup.php)


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

