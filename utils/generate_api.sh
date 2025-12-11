#!/bin/bash

set -eu

GITHUB_WORKSPACE="/home/jean/gitroot"
PROJECT_ROOT="/home/jean/gitroot/go-netbox"

# Create necessary folders
mkdir -p "${PROJECT_ROOT}/patches"
mkdir -p "${PROJECT_ROOT}/openapi"

get_last_netbox_version() {
  version=$1
  tags=""
  NEXT=""
  max=0
  i=0
  while [ "$NEXT" != "null" ]
  do
    i=$((i+1))
    JSON=$(curl https://registry.hub.docker.com/v2/repositories/netboxcommunity/netbox/tags/?page=$i\&page_size=1000 2>/dev/null)
    tags="$tags $(echo "$JSON" | jq -r '."results"[]["name"]' | grep "$version" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+\.[0-9]+$")"
    NEXT=$(echo "$JSON" | jq '."next"')
  done

  for t in $tags; do
    MAJOR=$(echo "$t" | cut -d"-" -f1 | cut -d"." -f3)
    if [ "$MAJOR" != "" ] && [ "$MAJOR" -gt "$max" ]; then
      max=$MAJOR
      docker="$(echo "$t" | cut -d"-" -f2)"
    fi
  done

  echo "$version.$max-$docker"
}

NETBOX_MAJOR_VERSION=$(cat netbox_major_version)
echo "NETBOX_MAJOR_VERSION=${NETBOX_MAJOR_VERSION}"

DOCKER_RESULT="$(get_last_netbox_version "${NETBOX_MAJOR_VERSION}")"

LAST_NETBOX_VERSION="$(echo "${DOCKER_RESULT}" | cut -d"-" -f1)"
echo "LAST_NETBOX_VERSION=${LAST_NETBOX_VERSION}"

DOCKER_VERSION="$(echo "${DOCKER_RESULT}" | cut -d"-" -f2)"
echo "DOCKER_VERSION=${DOCKER_VERSION}"
export VERSION=${LAST_NETBOX_VERSION}

echo "Purge old lib generated ..."
if [ -f "${PROJECT_ROOT}/.openapi-generator/files" ]; then
  while read -r file; do
    rm -f "${PROJECT_ROOT}/$file"
  done < "${PROJECT_ROOT}"/.openapi-generator/files
fi

rm -rf "${PROJECT_ROOT}/api" && mkdir -p "${PROJECT_ROOT}/api" \
  && touch "${PROJECT_ROOT}/api/.gitkeep"

if [ ! -f "${PROJECT_ROOT}/openapi/openapi-${VERSION}.yaml" ]; then
  echo "Get github project netbox-docker ..."
  echo "Get openapi from netbox docker ..."
  while ! curl -s http://localhost:8000/api/schema/ -o openapi.yaml 2> /dev/null; do sleep 1 && echo "Waiting docker to be up..."; done
  cp openapi.yaml "${PROJECT_ROOT}/openapi/openapi-${VERSION}.yaml"
  rm openapi.yaml
  cd "${PROJECT_ROOT}"/utils
fi

cp "${PROJECT_ROOT}/openapi/openapi-${VERSION}.yaml" "${PROJECT_ROOT}/api/openapi.yaml"
cp -r "${PROJECT_ROOT}"/utils/.openapi-generator* "${PROJECT_ROOT}"

echo "Patch openapi definition ..."
cd "${PROJECT_ROOT}"/utils
./fix-spec.py

# Generate library
docker run --rm --env JAVA_OPTS=-DmaxYamlCodePoints=9999999 -v "${PROJECT_ROOT}:/local" openapitools/openapi-generator-cli:v7.14.0 \
    generate \
    --config /local/.openapi-generator/config.yaml \
    --input-spec /local/api/openapi.yaml \
    --output /local \
    --inline-schema-options RESOLVE_INLINE_ENUMS=true \
    --http-user-agent go-netbox/"$(cat ../utils/netbox_major_version)"

echo "Apply patches manually ..."
sudo cp "${PROJECT_ROOT}"/patches/* "${PROJECT_ROOT}"

cd "${PROJECT_ROOT}"
echo "Execute go mod tidy ... "
go mod tidy

echo "Execute goimports ..."
find . -name "*.go" -exec goimports -w {} \;

echo "Cleaning ..."
cd "${PROJECT_ROOT}/utils"
rm -rf netbox-docker
rm -f swagger
rm -f swagger.json
rm -f ../netbox/openapi-"${VERSION}".yaml.*
