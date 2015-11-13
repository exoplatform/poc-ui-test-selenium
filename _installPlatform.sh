#!/bin/bash -eu

PLF_VERSION=${PLF_VERSION:?mandatory}
PLF_ARTIFACT_ARTIFACTID=${PLF_ARTIFACT_ARTIFACTID:?mandatory}
PLF_ARTIFACT_GROUPID=${PLF_ARTIFACT_GROUPID:?mandatory}
TS_TIMESTAMP=${TS_TIMESTAMP:?mandatory}
PLF_VOLUME_NAME=${PLF_NAME:?Mandatory}

QA_NEXUS_USER=${QA_NEXUS_USER:?Mandatory}
QA_NEXUS_PASSWORD=${QA_NEXUS_PASSWORD:?Mandatory}

#### Create volumes
PLF_INSTALL_VOLUME=$(docker volume create --name ${PLF_VOLUME_NAME})
DOWNLOADS_VOLUME=$(docker volume create --name plf_artifacts_downloads)

## Download and install PLF
docker run -v ${PLF_INSTALL_VOLUME}:/srv -v ${DOWNLOADS_VOLUME}:/downloads -e OFFLINE=${OFFLINE} -e VERSION=${PLF_VERSION} -e REPOSITORY_USERNAME=${QA_NEXUS_USER} -e REPOSITORY_PASSWORD=${QA_NEXUS_PASSWORD} -e PLF_ARTIFACT_GROUPID=${PLF_ARTIFACT_GROUPID} -e PLF_ARTIFACT_ARTIFACTID=${PLF_ARTIFACT_ARTIFACTID} --name ${PLF_INSTALL_VOLUME}_installer ${PLF_INSTALLER_IMAGE} 1>&2
# Dont use directly --rm in the previous command to avoid removing the volumes
docker rm ${PLF_INSTALL_VOLUME}_installer > /dev/null

export PLF_VOLUME=${PLF_INSTALL_VOLUME}
