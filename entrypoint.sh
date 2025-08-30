#!/usr/bin/env bash
set -euo pipefail

# Define vars (use safe defaults so -u won't fail)
: "${GITHUB_ACTIONS:=false}"
: "${GITHUB_SHA:=main}"

# Inputs (provide safe defaults)
: "${MPY_TARGET:=build}"
: "${MPY_PLATFORM:=}"
: "${MPY_BOARD:=}"
: "${MPY_BOARDS:=}"
: "${MPY_FLAGS:=}"

# Try fetching the SHA from both remotes
if ! git rev-parse "${GITHUB_SHA}" >/dev/null 2>&1; then
    echo "SHA ${GITHUB_SHA} not found locally. Fetching from origin..."
    git fetch origin "${GITHUB_SHA}" --tags --prune || echo "SHA not found in origin."
fi
# Final check: If SHA still doesn't exist, fail
if ! git rev-parse "${GITHUB_SHA}" >/dev/null 2>&1; then
    echo "Error: SHA ${GITHUB_SHA} not found in either remote."
    exit 1
fi
# Reset to the target SHA
git reset --hard "${GITHUB_SHA}"

# Espressif IDF
if [[ ${MPY_PLATFORM} == "esp32" ]]; then
	export IDF_PATH=/opt/esp-idf
	export IDF_TOOLS_PATH=/opt/esp-idf-tools
	export ESP_ROM_ELF_DIR=/opt/esp-idf-tools
	source "${IDF_PATH}/export.sh"
fi

make -j"$(nproc)" -C mpy-cross
make -C ports/${MPY_PLATFORM} submodules

# Build
if [[ ${MPY_TARGET} == "build" ]]; then
	echo "Building MicroPython: ${MPY_PLATFORM}:${MPY_BOARD}"
	make -j"$(nproc)" -C "ports/${MPY_PLATFORM}" BOARD="${MPY_BOARD}" $MPY_FLAGS
	echo "Build artifacts are located at: /workspace/ports/${MPY_PLATFORM}/build-${MPY_BOARD}"
fi

# Release
if [[ ${MPY_TARGET} == "release" ]]; then
	echo "Building MicroPython release: ${MPY_PLATFORM}:${MPY_BOARDS}"
	JOBS=$(nproc)
	PIDS=()
	COUNT=0
	for BOARD in ${MPY_BOARDS}; do
		echo "Building for board: $BOARD"
		make -j"$JOBS" -C "ports/${MPY_PLATFORM}" BOARD="$BOARD" $MPY_FLAGS &
		PIDS+=("$!")
		COUNT=$((COUNT+1))
		if (( COUNT % JOBS == 0 )); then
			wait
		fi
	done
	wait
	mkdir -p /workspace/bin
	for BOARD in ${MPY_BOARDS}; do
		for OUTDIR in /workspace/ports/${MPY_PLATFORM}/build-${BOARD}*; do
			if [ -d "$OUTDIR" ]; then
				DESTDIR="/workspace/bin/${BOARD}"
				mkdir -p "$DESTDIR"
				find "$OUTDIR" -maxdepth 1 -type f \( -name '*.uf2' -o -name '*.bin' -o -name '*.hex' \) -exec cp {} "$DESTDIR" \;
			fi
		done
	done
	echo "Build artifacts are located at: /workspace/bin/"
fi
