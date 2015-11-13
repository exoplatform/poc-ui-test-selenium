#!/bin/bash -eu

export DOCKER_HOST=${QA_DOCKER_HOST:?QA_DOCKER_HOST is mandatory}

export OFFLINE=${OFFLINE:false}

export DB_TYPE=mysql
export DB_VERSION=5.5

export PLF_ARTIFACT_GROUPID=com.exoplatform.platform.distributions
export PLF_ARTIFACT_ARTIFACTID=plf-enterprise-tomcat-standalone
export PLF_VERSION=4.3.x-SNAPSHOT

#export PLF_ARTIFACT_GROUPID=${QA_PLF_ARTIFACT_GROUPID:?Mandatory}
#export PLF_ARTIFACT_ARTIFACTID=${QA_PLF_ARTIFACT_ARTIFACTID:?Mandatory}
#export PLF_VERSION=${QA_PLF_VERSION:?Mandatory}

export PLF_INSTALLER_IMAGE=plf-installer

export TS_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
#export TS_TIMESTAMP=20151113-021923
export PLF_NAME=${PLF_ARTIFACT_ARTIFACTID}_${PLF_VERSION}_${TS_TIMESTAMP}

export NEXUS_USER=${QA_NEXUS_USER:?Mandatory}
export NEXUS_USER=${QA_NEXUS_PASSWORD:?Mandatory}

function finish {
  echo INFO Cleaning database container ${DB_CONTAINER_ID} ...
  docker kill ${DB_CONTAINER_ID}
  docker rm -v ${DB_CONTAINER_ID}

  echo INFO Cleaning PLF container ${DB_CONTAINER_ID} ...
  docker kill ${PLF_NAME}
  docker rm ${PLF_NAME}
}
trap finish EXIT

type docker > /dev/null
if [ $? -ne 0 ]
then
  echo "ERROR Docker command line not found in path"
  exit 1
fi

eval $(./_installPlatform.sh)
echo [INFO] Platform installed on volume ${PLF_NAME}

eval $(./_startDatabaseContainer.sh)

./_startPlatform.sh
