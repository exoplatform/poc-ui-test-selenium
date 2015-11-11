#!/bin/bash -eu

# #############################################################################
# Initialize
# #############################################################################
SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Load env settings
source ${SCRIPT_DIR}/_setenv.sh
# Load common functions
source ${SCRIPT_DIR}/_functions.sh

function usage {
 echo "Usage: $0 <PLF_VERSION>"
}

if [ $# -lt 1 ]; then
 echo ">>> Missing arguments"
 usage
 exit;
fi;

VERSION=$1

# Remove old binaries
## TODO Move on AMI
mkdir -p ${DL_DIR}

find ${DL_DIR} -mtime +28 -name "${PLF_NAME}-*" -exec rm {} \;

# Download archive

do_download_from_nexus  \
 "${REPOSITORY_URL}" "${REPOSITORY_USERNAME}" "${REPOSITORY_PASSWORD}"  \
 "${PLF_ARTIFACT_GROUPID}" "${PLF_ARTIFACT_ARTIFACTID}" "${VERSION}" "${PLF_ARTIFACT_PACKAGING}" "${PLF_ARTIFACT_CLASSIFIER}"  \
 "${DL_DIR}" "${PLF_NAME}" "PLF"
source ${DL_DIR}/${PLF_NAME}-${VERSION}.info
