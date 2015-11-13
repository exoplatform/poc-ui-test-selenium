#!/bin/bash -eu

export BUILD_ID=${BUILD_ID:"undef"}

source ${BASEDIR}/_functions_docker.sh
source ${BASEDIR}/env.${BUILD_ID}

echo "INFO Cleaning database container"
docker rm -f ${DB_CONTAINER_ID}

echo "INFO Cleaning PLF container"
docker rm -f ${PLF_NAME}
