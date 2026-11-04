#!/usr/bin/env bash

# TWRP build script

set -o pipefail

VERSION="1.0"
BUILD_TYPE="normal"
CONFIG_FILE=""

header() {
    cat <<EOF
==========================================
  TWRP Builder v${VERSION}
  Build type : ${BUILD_TYPE}
  Config     : ${CONFIG_FILE}
==========================================
EOF
}

usage() {
    cat <<EOF
TWRP Builder v${VERSION}

Usage: $(basename "$0") [options]

Options:
  --build_type <type>   normal (default) or clean
  --config <file>       Config file to source
                        (default: /twrp/\${RepositoryName}/config.sh)
  -h, --help            Show this help and exit

Config variables:
  MANIFEST_URL, MANIFEST_BRANCH      Repo manifest to sync
  DEVICE_TREE_URL, DEVICE_TREE_BRANCH, DEVICE_PATH     Devive Tree Setup
  COMMON_TREE_URL, COMMON_DEVICE_TREE_BRANCH, COMMON_PATH   (optional)
  MAKEFILE_NAME, BUILD_TARGET        e.g. twrp_pissarro / boot
  SWAP_SIZE                          Swap size in GB (optional)
  SWAP_FILE                          Swap file path, always kept in /tmp (default /tmp/swapfile)
  UPLOAD_CCACHE                      Set to upload ccache after build
  TG_CHAT_ID, TG_TOKEN               Telegram notifications (optional)

Examples:
  $(basename "$0")
  $(basename "$0") --build_type clean
  $(basename "$0") --config ./my_config.sh
EOF
}

tg() {
    local msg="$1"
    if [[ -n ${TG_CHAT_ID} && -n ${TG_TOKEN} ]]; then
        curl -s "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
            --data-urlencode "text=${msg}" \
            --data-urlencode "chat_id=${TG_CHAT_ID}" >/dev/null
    fi
}

die() {
    echo "ERROR: $*" >&2
    tg "BUILD FAILED: $*"
    exit 1
}

run_step() {
    local name="$1"; shift
    echo
    echo ">>> ${name}"
    if ! "$@"; then
        die "${name} failed"
    fi
    echo "<<< ${name} OK"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --build_type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        --build_type=*)
            BUILD_TYPE="${1#*=}"
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --config=*)
            CONFIG_FILE="${1#*=}"
            shift
            ;;
        clean)  # backwards compatibility with old "./build.sh clean"
            BUILD_TYPE="clean"
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

case "${BUILD_TYPE}" in
    normal|clean) ;;
    *) echo "Invalid --build_type '${BUILD_TYPE}' (use normal or clean)" >&2; exit 1 ;;
esac

CONFIG_FILE="${CONFIG_FILE:-/twrp/${RepositoryName}/config.sh}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

header

setup_swap() {
    if [[ -z ${SWAP_SIZE} ]]; then
        echo "SWAP_SIZE not set, skipping swap setup"
        return 0
    fi

    local size="${SWAP_SIZE^^}"
    size="${size%B}"
    local num unit
    if [[ "${size}" =~ ^([0-9]+)([MG]?)$ ]]; then
        num="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]:-G}"
    else
        echo "Invalid SWAP_SIZE '${SWAP_SIZE}' (use e.g. 16, 16G or 8192M)"
        return 1
    fi

    local swapfile="${SWAP_FILE:-${SWAPFILE:-/tmp/swapfile}}"
    case "${swapfile}" in
        /tmp/*) ;;
        *)
            echo "SWAP_FILE '${swapfile}' is outside /tmp, using /tmp/$(basename "${swapfile}")"
            swapfile="/tmp/$(basename "${swapfile}")"
            ;;
    esac
    local want
    if [[ "${unit}" == "G" ]]; then
        want=$(( 10#${num} * 1024 * 1024 * 1024 ))
    else
        want=$(( 10#${num} * 1024 * 1024 ))
    fi
    local label="${num}${unit}"

    if [[ -f "${swapfile}" ]]; then
        local have
        have=$(stat -c %s "${swapfile}")
        if [[ "${have}" -eq "${want}" ]] && swapon --show=NAME --noheadings | grep -qx "${swapfile}"; then
            echo "Swap already ${label} and active, nothing to do"
            return 0
        fi
        echo "Swap differs (or inactive), recreating as ${label}"
        sudo swapoff "${swapfile}" 2>/dev/null
        sudo rm -f "${swapfile}" || return 1
    fi

    mkdir -p "$(dirname "${swapfile}")" 2>/dev/null
    sudo fallocate -l "${label}" "${swapfile}" || return 1
    sudo chmod 600 "${swapfile}"                    || return 1
    sudo mkswap "${swapfile}"                       || return 1
    if ! sudo swapon "${swapfile}"; then
        echo "swapon failed, retrying with a dd-allocated file"
        sudo swapoff "${swapfile}" 2>/dev/null
        sudo rm -f "${swapfile}"
        local mb=$(( want / 1024 / 1024 ))
        sudo dd if=/dev/zero of="${swapfile}" bs=1M count="${mb}" status=none || return 1
        sudo chmod 600 "${swapfile}"                    || return 1
        sudo mkswap "${swapfile}"                       || return 1
        sudo swapon "${swapfile}"                       || return 1
    fi
    echo "Swap enabled: ${label} at ${swapfile}"
}

dl_ccache() {

if [[ -n "${CCACHE_URL}" ]]; then
 cd /tmp
 tg "Downloading Ccache!"
 time aria2c "${CCACHE_URL}" -x16 -s50
 time tar xf ccache.tar.gz
 rm -rf ccache.tar.gz
 cd /twrp
fi

}

repo_sync() {
    tg "$(cat <<EOF
REPO SYNC STARTED!

MANIFEST_URL: ${MANIFEST_URL}
MANIFEST_BRANCH: ${MANIFEST_BRANCH}
EOF
)"
    repo init --depth=1 -u "${MANIFEST_URL}" -b "${MANIFEST_BRANCH}" || return 1
    repo sync -j"$(nproc --all)"                                     || return 1
}

clone_dt() {
    tg "$(cat <<EOF
CLONING DEVICE TREE
DT URL: ${DEVICE_TREE_URL}
DT BRANCH: ${DEVICE_TREE_BRANCH}
DT PATH: ${DEVICE_PATH}
EOF
)"
    rm -rf "${DEVICE_PATH}"
    git clone "${DEVICE_TREE_URL}" -b "${DEVICE_TREE_BRANCH}" "${DEVICE_PATH}"
}

clone_cdt() {
    rm -rf "${COMMON_PATH}"
    git clone "${COMMON_TREE_URL}" -b "${COMMON_DEVICE_TREE_BRANCH}" "${COMMON_PATH}"
}

build() {
    tg "$(cat <<EOF
Build Started:
Build: ${BUILD_TYPE}
MAKEFILE: ${MAKEFILE_NAME}
BUILD TARGET: ${BUILD_TARGET}image
EOF
)"
    source build/envsetup.sh
    export ALLOW_MISSING_DEPENDENCIES=true
    lunch "${MAKEFILE_NAME}-eng" || return 1

  if [[ "${UPLOAD_CCACHE}" == "y" ]]; then

    if [[ "${BUILD_TYPE}" == "clean" ]]; then
        make clean || return 1
    fi

    export CCACHE_DIR=/tmp/ccache
    export CCACHE_EXEC=$(which ccache)
    export USE_CCACHE=1
    ccache -M 12G
    ccache -o compression=true
    ccache -z
    make "${BUILD_TARGET}image" -j"$(nproc --all)" || return 1
    tg "Build Completed!"
  else
    if [[ "${BUILD_TYPE}" == "clean" ]]; then
        make clean || return 1
    fi
    make "${BUILD_TARGET}image" -j"$(nproc --all)" || return 1
    tg "Build Completed!"
  fi
}

up_recovery() {
    local img="${OUT}/${BUILD_TARGET}.img"
    [[ -f "${img}" ]] || { echo "Image not found: ${img}"; return 1; }
    cd "${OUT}" || return 1
    rm -f upload.txt
    curl https://sendit.sh -T "${BUILD_TARGET}.img" > upload.txt || return 1
    tg "$(cat upload.txt)"
}

up_ccache() {
    cd /tmp || return 1
    rm -f ccache.tar.gz upload.txt
    time tar --use-compress-program="pigz -k -1" -cf ccache.tar.gz ccache || return 1
    curl https://sendit.sh -T ccache.tar.gz > upload.txt                  || return 1
    tg "$(cat upload.txt)"
}

cat <<EOF
BUILD FLAGS:
MANIFEST_URL: ${MANIFEST_URL}
MANIFEST_BRANCH: ${MANIFEST_BRANCH}
DEVICE_TREE_URL: ${DEVICE_TREE_URL}
DEVICE_TREE_BRANCH: ${DEVICE_TREE_BRANCH}
MAKEFILE_NAME: ${MAKEFILE_NAME}
BUILD_TARGET: ${BUILD_TARGET}
BUILD_TYPE: ${BUILD_TYPE}
SWAP_SIZE: ${SWAP_SIZE:-unset}
UPLOAD_CCACHE: ${UPLOAD_CCACHE:-unset}
EOF

[[ -d /twrp ]] || die "/twrp does not exist"
cd /twrp || die "cannot cd to /twrp"

run_step "Swap setup" setup_swap

if [[ -n ${CCACHE_URL} ]]; then
    run_step "Downloading Ccache" dl_ccache
fi

if [[ -n ${MANIFEST_URL} && -n ${MANIFEST_BRANCH} ]]; then
    run_step "Repo sync" repo_sync
fi

if [[ -n ${DEVICE_TREE_URL} && -n ${DEVICE_TREE_BRANCH} && -n ${DEVICE_PATH} ]]; then
    run_step "Clone device tree" clone_dt
fi

if [[ -n ${COMMON_TREE_URL} && -n ${COMMON_DEVICE_TREE_BRANCH} && -n ${COMMON_PATH} ]]; then
    run_step "Clone common tree" clone_cdt
fi

if [[ -n ${MAKEFILE_NAME} && -n ${BUILD_TARGET} ]]; then
    run_step "Build (${BUILD_TYPE})" build
    run_step "Upload recovery"       up_recovery
else
    die "MAKEFILE_NAME and BUILD_TARGET must be set in config"
fi

if [[ -n ${UPLOAD_CCACHE} ]]; then
    run_step "Upload ccache" up_ccache
fi

echo
echo "All steps completed successfully."
tg "All steps completed successfully."
