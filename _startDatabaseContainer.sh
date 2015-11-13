#!/bin/bash -eu
## A script to start a database container
## must define these variables
## - DB_URL
## - DB_USER
## - DB_PASSWORD
## - DB_CONTAINER_ID

DB_TYPE=${DB_TYPE:?DB_TYPE is mandatory}
DB_VERSION=${DB_VERSION:?DB_VERSION is mandatory}

DOCKER_HOST=${DOCKER_HOST:?DOCKER_HOST is mandatory}

./_startDatabaseContainer-${DB_TYPE}.sh
