#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly TEST_ROOT="$(mktemp --directory)"

cleanup() {
    rm -rf "${TEST_ROOT}"
}
trap cleanup EXIT

mkdir --parents "${TEST_ROOT}/bin" "${TEST_ROOT}/install"

printf '#!/usr/bin/env bash\nexit 0\n' >"${TEST_ROOT}/bin/steamcmd.sh"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >"${TEST_OUTPUT}"\n' >"${TEST_ROOT}/install/ProjectZomboid64"
printf '{"vmArgs":["-Xmx8g"]}\n' >"${TEST_ROOT}/install/ProjectZomboid64.json"
chmod 755 "${TEST_ROOT}/bin/steamcmd.sh" "${TEST_ROOT}/install/ProjectZomboid64"

PATH="${TEST_ROOT}/bin:${PATH}" \
ZOMBOID_INSTALL_DIR="${TEST_ROOT}/install" \
ZOMBOID_DATA_DIR="${TEST_ROOT}/server" \
SERVER_NAME=integration \
ADMIN_PASSWORD=secret \
STEAM_VAC=false \
SERVER_MEMORY=4G \
STEAMCMD_RETRIES=1 \
WORKSHOP_ITEMS='1234567890, 2345678901' \
MOD_IDS='ExampleMod; ExampleMap' \
MAPS='Example Map;Muldraugh, KY' \
TEST_OUTPUT="${TEST_ROOT}/arguments" \
bash "${REPOSITORY_ROOT}/entrypoint.sh"

config_file="${TEST_ROOT}/server/Server/integration.ini"
grep --fixed-strings --line-regexp 'WorkshopItems=1234567890;2345678901' "${config_file}"
grep --fixed-strings --line-regexp 'Mods=ExampleMod;ExampleMap' "${config_file}"
grep --fixed-strings --line-regexp 'Map=Example Map;Muldraugh, KY' "${config_file}"
grep --fixed-strings --line-regexp -- '-cachedir='"${TEST_ROOT}"'/server' "${TEST_ROOT}/arguments"
grep --fixed-strings --line-regexp -- '-servername' "${TEST_ROOT}/arguments"
grep --fixed-strings --line-regexp 'integration' "${TEST_ROOT}/arguments"
grep --fixed-strings --line-regexp 'secret' "${TEST_ROOT}/arguments"
grep --fixed-strings -- '"-Xmx4G"' "${TEST_ROOT}/install/ProjectZomboid64.json"

if PATH="${TEST_ROOT}/bin:${PATH}" \
    ZOMBOID_INSTALL_DIR="${TEST_ROOT}/install" \
    ZOMBOID_DATA_DIR="${TEST_ROOT}/invalid" \
    SERVER_NAME='../escape' \
    TEST_OUTPUT="${TEST_ROOT}/invalid-arguments" \
    bash "${REPOSITORY_ROOT}/entrypoint.sh" >/dev/null 2>&1; then
    echo "Entrypoint accepted an unsafe server name" >&2
    exit 1
fi

if PATH="${TEST_ROOT}/bin:${PATH}" \
    ZOMBOID_INSTALL_DIR="${TEST_ROOT}/install" \
    ZOMBOID_DATA_DIR="${TEST_ROOT}/invalid" \
    WORKSHOP_ITEMS='not-an-id' \
    TEST_OUTPUT="${TEST_ROOT}/invalid-arguments" \
    bash "${REPOSITORY_ROOT}/entrypoint.sh" >/dev/null 2>&1; then
    echo "Entrypoint accepted an invalid Workshop item ID" >&2
    exit 1
fi

echo "Entrypoint configuration tests passed"
