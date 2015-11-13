#!/bin/bash

# #############################################################################
# Initialize
# #############################################################################                                              SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source _functions_download.sh
source _functions.sh

#do_download_server https://repository.exoplatform.com
source ./_downloadPLF.sh ${VERSION}

mkdir -p ${PLF_SRV_DIR}

echo ""
echo "[INFO] ======================================="
echo "[INFO] = Extract ${PLF_NAME} ${VERSION} ..."
echo "[INFO] ======================================="

rm -rf ${PLF_SRV_DIR}/${PLF_NAME}-${VERSION}
mkdir -p ${PLF_SRV_DIR}/${PLF_NAME}-${VERSION}

echo "[INFO] Uncompressing ${PLF_ARTIFACT_LOCAL_PATH} in  to ${PLF_SRV_DIR}/${PLF_NAME}-${VERSION} ..."

display_time unzip -q ${PLF_ARTIFACT_LOCAL_PATH} -d ${PLF_SRV_DIR}/${PLF_NAME}-${VERSION}
if [ "$?" -ne "0" ]; then
  echo "[ERROR] Unable to unpack the server."
  exit 1
fi

echo ""
echo "[INFO] ======================================="
echo "[INFO] = Configure intance ${PLF_NAME} ${VERSION} ..."
echo "[INFO] ======================================="
rm -f ${PLF_SRV_DIR}/current
ln -fs ${PLF_SRV_DIR}/${PLF_NAME}-${VERSION}/platform-${VERSION} ${PLF_SRV_DIR}/current

ln -fs ${PLF_SRV_DIR}/bin/_setenv.sh ${PLF_SRV_DIR}/current/bin/setenv-local.sh
mv ${PLF_SRV_DIR}/current/conf/server.xml ${PLF_SRV_DIR}/current/conf/server.xml.ori
cp ${PLF_SRV_DIR}/current/conf/server-mysql.xml ${PLF_SRV_DIR}/current/conf/server.xml

#ln -fs ${PLF_SRV_DIR}/bin/_setenv.sh ${PLF_SRV_DIR}/current/bin/setenv-local.sh
mv ${PLF_SRV_DIR}/current/conf/server.xml ${PLF_SRV_DIR}/current/conf/server.xml.ori
cp ${PLF_SRV_DIR}/current/conf/server-mysql.xml ${PLF_SRV_DIR}/current/conf/server.xml

sed -i 's/localhost:3306/db:3306/g' ${PLF_SRV_DIR}/current/conf/server.xml

MYSQL_JAR_URL="http://repository.exoplatform.org/public/mysql/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/mysql-connector-java-${DEPLOYMENT_MYSQL_DRIVER_VERSION}.jar"
pushd .

mkdir -p ${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/
echo "[INFO] Downloading MySQL JDBC driver from ${MYSQL_JAR_URL} ..."
set +e
curl --fail --show-error --location-trusted ${MYSQL_JAR_URL} > ${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/`basename ${MYSQL_JAR_URL}`
if [ "$?" -ne "0" ]; then
  echo "[ERROR] Cannot download ${MYSQL_JAR_URL}"
  rm -f "${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/"`basename ${MYSQL_JAR_URL}` # Remove potential corrupted file
  exit 1
fi
set -e
echo "[INFO] Done."

cp -f "${DL_DIR}/mysql-connector-java/${DEPLOYMENT_MYSQL_DRIVER_VERSION}/"`basename ${MYSQL_JAR_URL}` ${PLF_SRV_DIR}/current/lib


set -e
echo "[INFO] Done"

echo "[INFO] ======================================="
echo "[INFO] = Installing Acme addon"
echo "[INFO] ======================================="
${PLF_SRV_DIR}/current/addon install exo-acme-sample:${VERSION}
