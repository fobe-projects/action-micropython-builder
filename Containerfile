FROM python:3.13-slim-bookworm AS base

ENV PIP_ROOT_USER_ACTION=ignore

WORKDIR /workspace

# Apt dependencies
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y \
    jq jdupes build-essential \
    libgpiod-dev libyaml-cpp-dev libbluetooth-dev libusb-1.0-0-dev libi2c-dev libuv1-dev \
    libx11-dev libinput-dev libxkbcommon-x11-dev \
    openssl libssl-dev libulfius-dev liborcania-dev \
    git git-lfs gettext cmake mtools floppyd dosfstools ninja-build \
    parted zip wget curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --upgrade pip setuptools wheel build huffman poetry

FROM base AS repo

ARG WORKSPACE_REPO="https://github.com/fobe-projects/micropython.git"
ARG WORKSPACE_REPO_UPSTREAM="https://github.com/micropython/micropython.git"
ARG WORKSPACE_REPO_REMOTE="origin"
ARG WORKSPACE_REPO_REF="main"

RUN git config --global --add safe.directory /workspace \
    && git clone "${WORKSPACE_REPO}" /workspace \
    && git remote add upstream "${WORKSPACE_REPO_UPSTREAM}" \
    && git fetch upstream --tags --prune --force \
    && git fetch origin --tags --prune --force \
    && git reset --hard "${WORKSPACE_REPO_REMOTE}/${WORKSPACE_REPO_REF}" \
    && git repack -d

ARG WORKSPACE_BUILD_REMOTE="origin"
ARG WORKSPACE_BUILD_REF="main"
RUN echo "Hard reset repository to: ${WORKSPACE_REPO_REMOTE}/${WORKSPACE_REPO_REF}" \
    && git fetch upstream --tags --prune --force \
    && git fetch origin --tags --prune --force \
    && git fetch "${WORKSPACE_BUILD_REMOTE}" "${WORKSPACE_BUILD_REF}" \
    && git reset --hard FETCH_HEAD \
    && git repack -d \
    && echo "Repository firmware version: $(git describe --tags --dirty --always --match 'v[1-9].*')"

FROM repo AS nrf

ENV MPY_PORT=nrf

ARG ARM_TOOLCHAIN_EABI_VERSION="14.2.rel1"
RUN --mount=type=cache,target=/tmp/arm-toolchain-cache,id=arm-toolchain-eabi-${ARM_TOOLCHAIN_EABI_VERSION} \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then \
        TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/$ARM_TOOLCHAIN_EABI_VERSION/binrel/arm-gnu-toolchain-$ARM_TOOLCHAIN_EABI_VERSION-aarch64-arm-none-eabi.tar.xz"; \
        TOOLCHAIN_ARCHIVE="/tmp/arm-toolchain-cache/arm-gnu-toolchain-$ARM_TOOLCHAIN_EABI_VERSION-aarch64-arm-none-eabi.tar.xz"; \
    elif [ "$ARCH" = "amd64" ]; then \
        TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/$ARM_TOOLCHAIN_EABI_VERSION/binrel/arm-gnu-toolchain-$ARM_TOOLCHAIN_EABI_VERSION-x86_64-arm-none-eabi.tar.xz"; \
        TOOLCHAIN_ARCHIVE="/tmp/arm-toolchain-cache/arm-gnu-toolchain-$ARM_TOOLCHAIN_EABI_VERSION-x86_64-arm-none-eabi.tar.xz"; \
    else \
        echo "Unsupported architecture: $ARCH"; \
        exit 1; \
    fi && \
    mkdir -p /usr/local/arm-none-eabi && \
    if [ ! -f "$TOOLCHAIN_ARCHIVE" ]; then \
        curl -fsSL "$TOOLCHAIN_URL" -o "$TOOLCHAIN_ARCHIVE"; \
    fi && \
    tar -xJf "$TOOLCHAIN_ARCHIVE" -C /usr/local/arm-none-eabi --strip-components=1 && \
    for f in /usr/local/arm-none-eabi/bin/arm-none-eabi-*; do \
        ln -sf "$f" /usr/local/bin/$(basename "$f"); \
    done

RUN --mount=type=cache,target=/tmp/nrfutil-cache,id=nrfutil-tools \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then \
        TOOLCHAIN_URL="https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/aarch64-unknown-linux-gnu/nrfutil"; \
        TOOLCHAIN_ARCHIVE="/tmp/nrfutil-cache/nrfutil-arm64"; \
    elif [ "$ARCH" = "amd64" ]; then \
        TOOLCHAIN_URL="https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/x86_64-unknown-linux-gnu/nrfutil"; \
        TOOLCHAIN_ARCHIVE="/tmp/nrfutil-cache/nrfutil-amd64"; \
    else \
        echo "Unsupported architecture: $ARCH"; \
        exit 1; \
    fi && \
    mkdir -p /usr/local/nrfutil && \
    if [ ! -f "$TOOLCHAIN_ARCHIVE" ]; then \
        curl -fsSL "$TOOLCHAIN_URL" -o "$TOOLCHAIN_ARCHIVE"; \
    fi && \
    cp "$TOOLCHAIN_ARCHIVE" /usr/local/nrfutil/nrfutil && \
    chmod +x /usr/local/nrfutil/nrfutil && \
    /usr/local/nrfutil/nrfutil install nrf5sdk-tools; \
    ln -sf /usr/local/nrfutil/nrfutil /usr/local/bin/nrfutil

RUN make -C ports/"${MPY_PORT}" submodules && git repack -d

RUN ports/nrf/drivers/bluetooth/download_ble_stack.sh

COPY --chmod=0755 entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

FROM repo AS esp32

ENV MPY_PORT=esp32
ENV IDF_PATH=/opt/esp-idf
ENV IDF_TOOLS_PATH=/opt/esp-idf-tools
ENV ESP_ROM_ELF_DIR=/opt/esp-idf-tools

ARG IDF_VERSION=v5.4.2
RUN git clone -b "${IDF_VERSION}" --recursive --depth 1 --shallow-submodules https://github.com/espressif/esp-idf.git "${IDF_PATH}"

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/opt/esp-idf-tools/dist \
    "${IDF_PATH}"/install.sh "esp32,esp32c2,esp32c3,esp32c6,esp32s2,esp32s3" > /dev/null 2>&1 \
    && bash -c "source ${IDF_PATH}/export.sh && pip3 install --upgrade minify-html jsmin sh requests-cache"

RUN bash -c "source ${IDF_PATH}/export.sh && make -C ports/esp32 submodules && git repack -d"

COPY --chmod=0755 entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]