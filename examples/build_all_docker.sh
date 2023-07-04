#!/usr/bin/env bash
set -ex

CHECK=0

pushd $(dirname ${BASH_SOURCE[0]})

# Loop through arguments and process them
VALID_ARGS=$(getopt -o c --long check,cargo-cache-dir: -- "$@")
if [[ $? -ne 0 ]]; then
    exit 1
fi

eval set -- "$VALID_ARGS"
args=()
while [ : ]; do
    case "$1" in
        -c | --check)
            CHECK=1
            shift
            ;;
        --cargo-cache-dir)
            args+=(--cargo-cache-dir "$2")
            shift 2
            ;;
        --)
            shift
            break
            ;;
    esac
done

echo "args: $args"

for d in "status-message/" $(ls -d */ | grep -v -e "status-message\/$"); do
    (./build_docker.sh ${d%%/} "${args[@]}")
done

if [ $CHECK == 1 ] && [ ! -z "$(git diff --exit-code)" ]; then
    echo "Repository is dirty, please make sure you have committed all contract wasm files"
    exit 1
fi
