#!/bin/bash -eu

source ./_functions_docker.sh

IMAGE=mysql
VERSION=${DB_VERSION}

MYSQL_ROOT=eXo # TODO random
MYSQL_DATABASE=plf
MYSQL_USER=plf
MYSQL_PASSWORD=plf

#docker run -ti -e MYSQL_ROOT_PASSWORD=eXo -e MYSQL_DATABASE=plf -e MYSQL_USER=plf -e MYSQL_PASSWORD=plf --name mysql mysql:5.5

echo "INFO Database starting ...." > /dev/stderr

DB_CONTAINER_ID=$(docker run -p 3306 -d -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT} -e MYSQL_DATABASE=${MYSQL_DATABASE} -e MYSQL_USER=${MYSQL_USER} -e MYSQL_PASSWORD=${MYSQL_PASSWORD} ${IMAGE}:${VERSION} )

DB_PORT=$(get_port_mapping ${DB_CONTAINER_ID})
DB_HOST=$(get_plf_host)

wait_open_port ${DB_HOST} ${DB_PORT}
echo "INFO Database available container=${DB_CONTAINER_ID}" > /dev/stderr

echo export DB_CONTAINER_ID=${DB_CONTAINER_ID}
echo export DB_URL=jdbc:mysql://db:3306
