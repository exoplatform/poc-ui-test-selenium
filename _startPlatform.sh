#!/bin/bash -eu

source ./_functions_docker.sh

PLF_VOLUME=${PLF_VOLUME-$PLF_NAME}

PLF_LAUNCHER_IMAGE=plf-runner

PLF_NAME=${PLF_NAME:?Mandatory}

PLF_CONTAINER=$(docker run -d -v ${PLF_VOLUME}:/srv -v ${PLF_NAME}:/srv --link ${DB_CONTAINER_ID}:db --name ${PLF_NAME} -p 8080 ${PLF_LAUNCHER_IMAGE})

PLF_URL=$(get_plf_url ${PLF_NAME})
PLF_PORT=$(get_port_mapping ${PLF_NAME})
PLF_HOST=$(get_plf_host)

echo "INFO Platform url ${PLF_URL}"

docker logs -f ${PLF_NAME} &

wait_open_port ${PLF_HOST} ${PLF_PORT}

echo "INFO PLF started and available at ${PLF_URL}"

echo "export PLF_URL=${PLF_URL}" >> env.${BUILD_ID}
