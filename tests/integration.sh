#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly IMAGE_NAME="${IMAGE_NAME:-docker-zomboid:test}"
readonly CONTAINER_NAME="docker-zomboid-test-${BASHPID}"
readonly VOLUME_NAME="docker-zomboid-test-${BASHPID}"

cleanup() {
    docker rm --force "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    docker volume rm "${VOLUME_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "${REPOSITORY_ROOT}"

if [[ "${BUILD_IMAGE:-true}" == true ]]; then
    docker build --tag "${IMAGE_NAME}" .
fi

docker volume create "${VOLUME_NAME}" >/dev/null
docker run \
    --detach \
    --name "${CONTAINER_NAME}" \
    --env ADMIN_PASSWORD=integration-only \
    --env SERVER_NAME=integration \
    --volume "${VOLUME_NAME}:/data" \
    "${IMAGE_NAME}" >/dev/null

for _ in {1..300}; do
    logs="$(docker logs "${CONTAINER_NAME}" 2>&1)"

    if grep --quiet 'SERVER STARTED' <<<"${logs}"; then
        docker stop --timeout 120 "${CONTAINER_NAME}" >/dev/null
        logs="$(docker logs "${CONTAINER_NAME}" 2>&1)"
        state="$(docker inspect --format '{{.State.Status}} {{.State.ExitCode}}' "${CONTAINER_NAME}")"
        if [[ "${state}" == 'exited 0' ]] \
            && grep --quiet 'saving the world' <<<"${logs}" \
            && grep --quiet 'World saved' <<<"${logs}"; then
            echo "Project Zomboid dedicated server startup and shutdown verified"
            exit 0
        fi

        docker logs "${CONTAINER_NAME}"
        echo "Unexpected container state after shutdown: ${state}" >&2
        exit 1
    fi

    if [[ "$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}")" != true ]]; then
        echo "${logs}"
        echo "Project Zomboid container exited before startup completed" >&2
        exit 1
    fi

    sleep 2
done

docker logs "${CONTAINER_NAME}"
echo "Project Zomboid did not complete startup within ten minutes" >&2
exit 1
