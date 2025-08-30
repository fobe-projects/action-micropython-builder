FROM python:3.13-bookworm AS base

ENV PIP_ROOT_USER_ACTION=ignore

# Apt dependencies
RUN apt-get update && apt-get install -y \
    jq jdupes build-essential \
    libgpiod-dev libyaml-cpp-dev libbluetooth-dev libusb-1.0-0-dev libi2c-dev libuv1-dev \
    libx11-dev libinput-dev libxkbcommon-x11-dev \
    openssl libssl-dev libulfius-dev liborcania-dev \
    git git-lfs gettext cmake mtools floppyd dosfstools ninja-build \
    parted zip \
    && rm -rf /var/lib/apt/lists/*

FROM base AS repo
ARG BUILD_REPO="https://github.com/fobe-projects/micropython.git"
ARG BUILD_REF="main"

WORKDIR /workspace

RUN git config --global --add safe.directory /workspace \
    && git config --global protocol.file.allow always \
    && git clone --depth 1 --filter=tree:0 "${BUILD_REPO}" /workspace \
    && cd /workspace && git checkout "${BUILD_REF}" \
    && git repack -d

RUN pip3 install --upgrade pip setuptools wheel build huffman poetry

FROM repo AS port

ARG ARM_TOOLCHAIN_EABI_VERSION="14.2.rel1"
ARG ARM_TOOLCHAIN_ELF_VERSION="13.3.rel1"
ARG BUILD_PLATFORM

RUN if [ "${BUILD_PLATFORM}" != "esp32" ] && [ "${BUILD_PLATFORM}" != "zephyr" ] && [ "${BUILD_PLATFORM}" != "none" ]; then \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then \
        TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/$ARM_TOOLCHAIN_EABI_VERSION/binrel/arm-gnu-toolchain-$ARM_TOOLCHAIN_EABI_VERSION-aarch64-arm-none-eabi.tar.xz"; \
    elif [ "$ARCH" = "amd64" ]; then \
        TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu/$ARM_TOOLCHAIN_EABI_VERSION/binrel/arm-gnu-toolchain-$ARM_TOOLCHAIN_EABI_VERSION-x86_64-arm-none-eabi.tar.xz"; \
    else \
        echo "Unsupported architecture: $ARCH"; \
        exit 1; \
    fi && \
    mkdir -p /usr/local/arm-none-eabi && \
    curl -fsSL "$TOOLCHAIN_URL" | tar -xJ -C /usr/local/arm-none-eabi --strip-components=1 && \
    for f in /usr/local/arm-none-eabi/bin/arm-none-eabi-*; do \
        ln -sf "$f" /usr/local/bin/$(basename "$f"); \
    done \
fi

# Nordic
RUN if [ "${BUILD_PLATFORM}" = "nrf" ]; then \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then \
        TOOLCHAIN_URL="https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/aarch64-unknown-linux-gnu/nrfutil"; \
    elif [ "$ARCH" = "amd64" ]; then \
        TOOLCHAIN_URL="https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/x86_64-unknown-linux-gnu/nrfutil"; \
    else \
        echo "Unsupported architecture: $ARCH"; \
        exit 1; \
    fi && curl -fsSL "$TOOLCHAIN_URL" -o nrfutil;\
    chmod +x nrfutil; \
    ./nrfutil install nrf5sdk-tools; \
    mv nrfutil /usr/local/bin; \
    nrfutil -V; \
    make -C ports/nrf submodules; \
    cd /workspace/ports/nrf && ./drivers/bluetooth/download_ble_stack.sh; \
    cd /workspace; \
fi

# Espressif IDF
ENV IDF_PATH=/opt/esp-idf
ENV IDF_TOOLS_PATH=/opt/esp-idf-tools
ENV ESP_ROM_ELF_DIR=/opt/esp-idf-tools
RUN if [ "${BUILD_PLATFORM}" = "esp32" ]; then \
    git clone -b v5.4.2 --recursive https://github.com/espressif/esp-idf.git ${IDF_PATH}; \
    $IDF_PATH/install.sh; \
    bash -c "source ${IDF_PATH}/export.sh && pip3 install --upgrade minify-html jsmin sh requests-cache && make -C ports/esp32 submodules"; \
    rm -rf $IDF_TOOLS_PATH/dist; \
fi

COPY --chmod=0755 entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]