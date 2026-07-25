#!/usr/bin/env bash

set -Eeuo pipefail

readonly APP_ID=380870
readonly INSTALL_DIR="${ZOMBOID_INSTALL_DIR:-/data/zomboid}"
readonly SERVER_DATA_DIR="${ZOMBOID_DATA_DIR:-/data/server}"
readonly EFFECTIVE_SERVER_NAME="${SERVER_NAME:-${SERVERNAME:-zomboid}}"

normalize_list() {
    local value="${1//,/;}"

    value="$(tr -d '[:space:]' <<<"${value}")"
    while [[ "${value}" == *';;'* ]]; do
        value="${value//;;/;}"
    done
    value="${value#;}"
    value="${value%;}"
    printf '%s' "${value}"
}

validate_workshop_items() {
    local value="$1"
    local item

    [[ -z "${value}" ]] && return
    IFS=';' read -r -a items <<<"${value}"
    for item in "${items[@]}"; do
        if [[ ! "${item}" =~ ^[0-9]+$ ]]; then
            echo "Invalid Steam Workshop item ID: ${item}" >&2
            return 1
        fi
    done
}

upsert_server_option() {
    local config_file="$1"
    local option="$2"
    local value="$3"
    local temporary_file
    local line
    local found=false

    temporary_file="$(mktemp "${config_file}.XXXXXX")"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        if [[ "${line}" == "${option}="* ]]; then
            if [[ "${found}" == false ]]; then
                printf '%s=%s\n' "${option}" "${value}" >>"${temporary_file}"
                found=true
            fi
        else
            printf '%s\n' "${line}" >>"${temporary_file}"
        fi
    done <"${config_file}"

    if [[ "${found}" == false ]]; then
        printf '%s=%s\n' "${option}" "${value}" >>"${temporary_file}"
    fi

    mv "${temporary_file}" "${config_file}"
}

configure_server() {
    local config_dir="${SERVER_DATA_DIR}/Server"
    local config_file="${config_dir}/${EFFECTIVE_SERVER_NAME}.ini"
    local workshop_items
    local mod_ids
    local maps

    if [[ ! -v WORKSHOP_ITEMS && ! -v MOD_IDS && ! -v MAPS ]]; then
        return
    fi

    workshop_items="$(normalize_list "${WORKSHOP_ITEMS:-}")"
    mod_ids="$(normalize_list "${MOD_IDS:-}")"
    maps="${MAPS:-}"
    if [[ "${maps}" == *$'\n'* || "${maps}" == *$'\r'* ]]; then
        echo "MAPS must be a single semicolon-separated line." >&2
        return 1
    fi
    validate_workshop_items "${workshop_items}"

    mkdir --parents "${config_dir}"
    touch "${config_file}"

    [[ -v WORKSHOP_ITEMS ]] && upsert_server_option "${config_file}" WorkshopItems "${workshop_items}"
    [[ -v MOD_IDS ]] && upsert_server_option "${config_file}" Mods "${mod_ids}"
    [[ -v MAPS ]] && upsert_server_option "${config_file}" Map "${maps}"
}

configure_memory() {
    local launcher_config="${INSTALL_DIR}/ProjectZomboid64.json"
    local temporary_file

    if [[ -z "${SERVER_MEMORY:-}" ]]; then
        return
    fi

    if [[ ! "${SERVER_MEMORY}" =~ ^[1-9][0-9]*[mMgG]$ ]]; then
        echo "SERVER_MEMORY must be a positive number followed by M or G, such as 4096M or 8G." >&2
        return 1
    fi

    if [[ ! -f "${launcher_config}" ]]; then
        echo "Project Zomboid launcher configuration is missing: ${launcher_config}" >&2
        return 1
    fi

    temporary_file="$(mktemp "${launcher_config}.XXXXXX")"
    sed --expression "s/\"-Xmx[^\"]*\"/\"-Xmx${SERVER_MEMORY}\"/" \
        "${launcher_config}" >"${temporary_file}"
    mv "${temporary_file}" "${launcher_config}"
}

if [[ ! "${EFFECTIVE_SERVER_NAME}" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "SERVER_NAME may contain only letters, numbers, underscores, and hyphens." >&2
    exit 1
fi

if [[ ! "${STEAMCMD_RETRIES:-3}" =~ ^[1-9][0-9]*$ ]]; then
    echo "STEAMCMD_RETRIES must be a positive integer." >&2
    exit 1
fi

if [[ "${STEAMCMD_VALIDATE:-false}" != true && "${STEAMCMD_VALIDATE:-false}" != false ]]; then
    echo "STEAMCMD_VALIDATE must be true or false." >&2
    exit 1
fi

steam_vac="${STEAM_VAC:-${STEAMVAC:-true}}"
if [[ "${steam_vac}" != true && "${steam_vac}" != false ]]; then
    echo "STEAM_VAC must be true or false." >&2
    exit 1
fi

admin_password="${ADMIN_PASSWORD:-${ADMINPASSWORD:-changeme}}"
if [[ -n "${ADMIN_PASSWORD_FILE:-}" ]]; then
    if [[ ! -r "${ADMIN_PASSWORD_FILE}" ]]; then
        echo "ADMIN_PASSWORD_FILE is not readable: ${ADMIN_PASSWORD_FILE}" >&2
        exit 1
    fi
    IFS= read -r admin_password <"${ADMIN_PASSWORD_FILE}" || true
fi

if [[ "${admin_password}" == changeme ]]; then
    echo "Warning: using the default administrator password; set ADMIN_PASSWORD before exposing the server." >&2
fi

mkdir --parents "${INSTALL_DIR}" "${SERVER_DATA_DIR}" "${SERVER_DATA_DIR}/mods"

steamcmd_update=(
    steamcmd.sh
    +force_install_dir "${INSTALL_DIR}"
    +login anonymous
    +app_update "${APP_ID}"
)

if [[ -n "${STEAM_BRANCH:-}" ]]; then
    steamcmd_update+=(-beta "${STEAM_BRANCH}")
    if [[ -n "${STEAM_BRANCH_PASSWORD:-}" ]]; then
        steamcmd_update+=(-betapassword "${STEAM_BRANCH_PASSWORD}")
    fi
fi

if [[ "${STEAMCMD_VALIDATE:-false}" == true ]]; then
    steamcmd_update+=(validate)
fi
steamcmd_update+=(+quit)

attempt=1
until steamcmd.sh +login anonymous +app_info_update 1 +app_info_print "${APP_ID}" +quit >/dev/null \
    && "${steamcmd_update[@]}"; do
    if (( attempt >= STEAMCMD_RETRIES )); then
        echo "SteamCMD update failed after ${attempt} attempts." >&2
        exit 1
    fi

    echo "SteamCMD update attempt ${attempt} failed; retrying." >&2
    sleep $((attempt * 5))
    ((attempt += 1))
done

configure_server
configure_memory

cd "${INSTALL_DIR}"
export PATH="${INSTALL_DIR}/jre64/bin:${PATH}"
export LD_LIBRARY_PATH="${INSTALL_DIR}/linux64:${INSTALL_DIR}/natives:${INSTALL_DIR}:${INSTALL_DIR}/jre64/lib/amd64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
if [[ -f "${INSTALL_DIR}/jre64/lib/libjsig.so" ]]; then
    export LD_PRELOAD="${INSTALL_DIR}/jre64/lib/libjsig.so${LD_PRELOAD:+:${LD_PRELOAD}}"
fi

console_dir="$(mktemp --directory)"
console_fifo="${console_dir}/stdin"
mkfifo "${console_fifo}"
exec 3<>"${console_fifo}"

shutdown_requested=false
shutdown_server() {
    if [[ "${shutdown_requested}" == false ]]; then
        shutdown_requested=true
        echo "Shutdown requested; saving the world and stopping the server."
        printf 'save\nquit\n' >&3
    fi
}
trap shutdown_server SIGINT SIGTERM

./ProjectZomboid64 \
    -cachedir="${SERVER_DATA_DIR}" \
    -servername "${EFFECTIVE_SERVER_NAME}" \
    -adminpassword "${admin_password}" \
    -steamvac "${steam_vac}" \
    "$@" <&3 &
server_pid=$!

set +e
wait "${server_pid}"
server_status=$?
while kill -0 "${server_pid}" 2>/dev/null; do
    wait "${server_pid}"
    server_status=$?
done
set -e

trap - SIGINT SIGTERM
exec 3>&-
rm -rf "${console_dir}"
exit "${server_status}"
