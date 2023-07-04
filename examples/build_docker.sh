#!/usr/bin/env bash

# Exit script as soon as a command fails.
set -ex

# Predefined ANSI escape codes for colors
YELLOW='\033[0;33m'
NC='\033[0m'

NAME="$1"
USER_ID="$(id -u)"
VALID_ARGS=$(getopt --long cargo-cache-dir: -- "$@")
if [[ $? -ne 0 ]]; then
    exit 1
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
    case "$1" in
        --cargo-cache-dir)
            CARGO_CACHE_HOST="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
    esac
done

# Switch to current directory (./examples) then out to root for specific examples
pushd $(dirname ${BASH_SOURCE[0]})
cd ../

SOURCE_HASH="$(echo $(pwd) | md5sum | awk '{print $1;}')"
CONT_NAME="build_${NAME}_$SOURCE_HASH"

# Pick the correct tag to pull from Docker Hub based on OS architecture
_warning="
${YELLOW}WARNING${NC}: You are building smart contracts using ARM64. The resulting artifacts will
be usable for testing, but won't pass the CI check for inclusion in master due to the
reproducibility requirements.
"
if [[ $(uname -m) == 'arm64' ]]; then
    echo -e "$_warning"
    TAG="latest-arm64"
else
    TAG="latest-amd64"
fi

OPTIONAL_MOUNTS=()
if [ ! -z $CARGO_CACHE_HOST ]; then
    CARGO_REGISTRY="$CARGO_CACHE_HOST/registry"
    CARGO_GIT="$CARGO_CACHE_HOST/git"
    mkdir -p "$CARGO_REGISTRY"
    mkdir -p "$CARGO_GIT"
    OPTIONAL_MOUNTS+=(-v "$CARGO_REGISTRY":/usr/local/cargo/registry)
    OPTIONAL_MOUNTS+=(-v "$CARGO_GIT":/usr/local/cargo/git)
fi

if docker ps -a --format '{{.Names}}' | grep -Eq "^$CONT_NAME\$"; then
    echo "Container exists"
else
    docker create \
        --mount type=bind,source=$(pwd),target=/host \
        "${OPTIONAL_MOUNTS[@]}" \
        --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
        --name="$CONT_NAME" \
        -w /host/examples/"$NAME" \
        -e RUSTFLAGS='-C link-arg=-s' \
        -e CARGO_TARGET_DIR='/host/docker-target' \
        -e USER_ID="$USER_ID" \
        -it nearprotocol/contract-builder:"$TAG" \
        /bin/bash
fi

docker start "$CONT_NAME"
docker exec -u $USER_ID "$CONT_NAME" /bin/bash -c "./build.sh"
