#!/bin/bash
#
# Generates go-netbox API client from OpenAPI spec.
#
# Usage:
#   ./generate_api.sh [options]
#
# Options:
#   --skip-docker          Skip Docker-based code generation
#   --skip-patches         Skip applying manual patches
#   --no-tests             Don't generate API test scaffolds (default: generate tests)
#   --run-tests            Run unit tests after generation
#   --run-integration      Run integration tests (requires NETBOX_URL, NETBOX_API_TOKEN)
#
# Examples:
#   ./generate_api.sh
#   ./generate_api.sh --run-tests
#   ./generate_api.sh --run-integration

set -eu

# Default options
SKIP_DOCKER=false
SKIP_PATCHES=false
GENERATE_TESTS=true
RUN_TESTS=false
RUN_INTEGRATION=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --skip-patches)
            SKIP_PATCHES=true
            shift
            ;;
        --no-tests)
            GENERATE_TESTS=false
            shift
            ;;
        --run-tests)
            RUN_TESTS=true
            shift
            ;;
        --run-integration)
            RUN_INTEGRATION=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

GITHUB_WORKSPACE="/home/jean/gitroot"
PROJECT_ROOT="/home/jean/gitroot/go-netbox"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Update config.yaml with GenerateTests setting
CONFIG_FILE="${SCRIPT_DIR}/.openapi-generator/config.yaml"
if [ -f "$CONFIG_FILE" ]; then
    if [ "$GENERATE_TESTS" = true ]; then
        sed -i 's/apiTests: false/apiTests: true/' "$CONFIG_FILE"
        echo "Set apiTests: true in config.yaml"
    else
        sed -i 's/apiTests: true/apiTests: false/' "$CONFIG_FILE"
        echo "Set apiTests: false in config.yaml"
    fi
fi

# Purge old lib generated (only if we're regenerating)
if [ "$SKIP_DOCKER" = false ]; then
    echo "Purge old lib generated ..."
    if [ -f "${PROJECT_ROOT}/.openapi-generator/files" ]; then
      while read -r file; do
        rm -f "${PROJECT_ROOT}/$file"
      done < "${PROJECT_ROOT}"/.openapi-generator/files
    fi
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

# Generate library (skip if --skip-docker)
if [ "$SKIP_DOCKER" = false ]; then
    docker run --rm --env JAVA_OPTS=-DmaxYamlCodePoints=9999999 -v "${PROJECT_ROOT}:/local" openapitools/openapi-generator-cli:v7.14.0 \
        generate \
        --config /local/.openapi-generator/config.yaml \
        --input-spec /local/api/openapi.yaml \
        --output /local \
        --inline-schema-options RESOLVE_INLINE_ENUMS=true \
        --http-user-agent go-netbox/"$(cat ../utils/netbox_major_version)"
else
    echo "Skipping Docker-based code generation (--skip-docker)"
fi

# Apply patches (skip if --skip-patches)
if [ "$SKIP_PATCHES" = false ]; then
    echo "Apply patches manually ..."
    # Note: Patch files have "//go:build ignore" on line 1 to exclude them from compilation.
    # This line must be stripped when copying to the project root.
    for patch in "${PROJECT_ROOT}"/patches/*.go; do
        if [ -f "$patch" ]; then
            dest="${PROJECT_ROOT}/$(basename "$patch")"
            # Remove the //go:build ignore line when copying
            tail -n +2 "$patch" > "$dest"
            echo "Applied patch: $(basename "$patch")"
        fi
    done
else
    echo "Skipping patches (--skip-patches)"
fi

cd "${PROJECT_ROOT}"
echo "Execute go mod tidy ... "
go mod tidy

echo "Execute goimports ..."
find . -name "*.go" -exec goimports -w {} \;

echo "Verify build ..."
go build .
echo "Build verified successfully!"

# Run unit tests if requested
if [ "$RUN_TESTS" = true ]; then
    echo "Running unit tests ..."
    go test ./... -v
    echo "Unit tests passed!"
fi

# Run integration tests if requested
if [ "$RUN_INTEGRATION" = true ]; then
    echo "Running integration tests ..."
    if [ -z "${NETBOX_URL:-}" ]; then
        export NETBOX_URL="http://localhost:8000"
        echo "NETBOX_URL not set, using default: $NETBOX_URL"
    fi
    if [ -z "${NETBOX_API_TOKEN:-}" ]; then
        echo "Warning: NETBOX_API_TOKEN not set. Integration tests may fail without authentication."
    fi
    go test -v ./test -tags=integration
    echo "Integration tests passed!"
fi

echo "Cleaning ..."
cd "${PROJECT_ROOT}/utils"
rm -rf netbox-docker
rm -f swagger
rm -f swagger.json
rm -f ../netbox/openapi-"${VERSION}".yaml.*

echo "========================================"
echo "go-netbox generation completed successfully!"
echo "========================================"
