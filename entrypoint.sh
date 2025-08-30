#!/usr/bin/env bash

set -euo pipefail

WORKSPACE=/workspace
JOBS=$(nproc)

# Define vars (use safe defaults so -u won't fail)
: "${GITHUB_ACTIONS:=false}"
# Inputs (provide safe defaults)
: "${REPO_REMOTE:=origin}"
: "${REPO_REF:=main}"
: "${BOARD:=}"

# Reset to the target SHA
git fetch upstream --tags --prune --force
git fetch origin --tags --prune --force
git fetch "${REPO_REMOTE}" "${REPO_REF}"
git reset --hard FETCH_HEAD
git repack -d

# Make the firmware tag
# final filename will be <BOARD><-VARIANT>-<DATE>-v<SEMVER>.ext
# where SEMVER is vX.Y.Z or vX.Y.Z-preview.N.gHASH or vX.Y.Z-preview.N.gHASH.dirty
FW_DATE=$(date '+%Y%m%d')
# same logic as makeversionhdr.py, convert git-describe output into semver-compatible
FW_GIT_TAG="$(git describe --tags --dirty --always --match 'v[1-9].*')"
FW_SEMVER_MAJOR_MINOR_PATCH="$(echo "${FW_GIT_TAG}" | cut -d'-' -f1)"
FW_SEMVER_PRERELEASE="$(echo "${FW_GIT_TAG}" | cut -s -d'-' -f2-)"
if [[ -z ${FW_SEMVER_PRERELEASE} ]]; then
    FW_SEMVER="${FW_SEMVER_MAJOR_MINOR_PATCH}"
else
    FW_SEMVER="${FW_SEMVER_MAJOR_MINOR_PATCH}-$(echo "${FW_SEMVER_PRERELEASE}" | tr - .)"
fi
FW_TAG="-${FW_DATE}-${FW_SEMVER}"
echo "Firmware version: ${FW_SEMVER}"
echo "Firmware tag: ${FW_TAG}"

# Espressif IDF
if [[ ${MPY_PORT} == "esp32" ]]; then
    export IDF_PATH=/opt/esp-idf
    export IDF_TOOLS_PATH=/opt/esp-idf-tools
    export ESP_ROM_ELF_DIR=/opt/esp-idf-tools
    # trunk-ignore(shellcheck/SC1091)
    source "${IDF_PATH}/export.sh"
fi

make -j"${JOBS}" -C mpy-cross
make -C ports/"${MPY_PORT}" submodules

# Build
echo "Build ${MPY_PORT} firmware: ${BOARD}"
mkdir -p "${WORKSPACE}/bin"

function copy_artefacts {
    local dest_dir=$1
    local descr=$2
    local fw_tag=$3
    local build_dir=$4
    shift 4
    for ext in "$@"; do
        dest=${dest_dir}/${descr}${fw_tag}.${ext}
        if [[ -r ${build_dir}/firmware.${ext} ]]; then
            mv "${build_dir}"/firmware."${ext}" "${dest}"
            elif [[ -r ${build_dir}/micropython.${ext} ]]; then
            # esp32 has micropython.elf, etc
            mv "${build_dir}"/micropython."${ext}" "${dest}"
            # trunk-ignore(shellcheck/SC2292)
            # trunk-ignore(shellcheck/SC2166)
            elif [ "${ext}" = app-bin -a -r "${build_dir}"/micropython.bin ]; then
            # esp32 has micropython.bin which is just the application
            mv "${build_dir}"/micropython.bin "${dest}"
        fi
    done
}

function build_board {
    # trunk-ignore(shellcheck/SC2002)
    DESCR=$(cat ports/"${MPY_PORT}"/boards/"${BOARD}"/board.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('id', '${BOARD}'))")
    # Build the "default" variant. For most boards this is the only thing we build.
    echo "building ${DESCR}"
    make -j"${JOBS}" -C ports/"${MPY_PORT}" BOARD="${BOARD}"
	if [[ ! -d ports/"${MPY_PORT}"/build-"${BOARD}" ]]; then
		mv ports/"${MPY_PORT}"/build-"${BOARD}"-* ports/"${MPY_PORT}"/build-"${BOARD}"
	fi
    copy_artefacts "${WORKSPACE}/bin" "${DESCR}" "${FW_TAG}" ports/"${MPY_PORT}"/build-"${BOARD}" "$@"
    # Query variants from board.json and build them.
    # trunk-ignore(shellcheck/SC2002)
    for VARIANT in $(cat ports/"${MPY_PORT}"/boards/"${BOARD}"/board.json | python3 -c "import json,sys; print(' '.join(json.load(sys.stdin).get('variants', {}).keys()))"); do
        echo "building variant ${DESCR} ${VARIANT}"
        make -j"${JOBS}" -C ports/"${MPY_PORT}" BOARD="${BOARD}" BOARD_VARIANT="${VARIANT}"
		if [[ ! -d ports/"${MPY_PORT}"/build-"${BOARD}"-"${VARIANT}" ]]; then
			mv ports/"${MPY_PORT}"/build-"${BOARD}"-"${VARIANT}"-* ports/"${MPY_PORT}"/build-"${BOARD}"-"${VARIANT}"
		fi
        copy_artefacts "${WORKSPACE}/bin" "${DESCR}-${VARIANT}" "${FW_TAG}" ports/"${MPY_PORT}"/build-"${BOARD}"-"${VARIANT}" "$@"
    done
}

if [[ ${MPY_PORT} == "alif" ]]; then
    build_board zip
fi

if [[ ${MPY_PORT} == "cc3200" ]]; then
    build_board zip
fi

if [[ ${MPY_PORT} == "esp32" ]]; then
    build_board bin elf map uf2 app-bin
fi

if [[ ${MPY_PORT} == "esp8266" ]]; then
    build_board bin elf map
fi

if [[ ${MPY_PORT} == "mimxrt" ]]; then
    build_board bin hex uf2
fi

if [[ ${MPY_PORT} == "nrf" ]]; then
    build_board bin hex uf2
fi

if [[ ${MPY_PORT} == "renesas_ra" ]]; then
    build_board bin hex
fi

if [[ ${MPY_PORT} == "rp2" ]]; then
    build_board uf2
fi

if [[ ${MPY_PORT} == "samd" ]]; then
    build_board uf2
fi

if [[ ${MPY_PORT} == "stm32" ]]; then
    build_board dfu hex
fi

echo "Build artifacts are located at: ${WORKSPACE}/bin"
