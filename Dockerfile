# --- Stage 1: Build OTBR ---
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Build dependencies
RUN apt-get update && apt-get install -y \
    lsb-release \
    git build-essential cmake ninja-build pkg-config \
    libssl-dev libdbus-1-dev libavahi-client-dev \
    libreadline-dev libsystemd-dev libglib2.0-0 \
    python3 python3-pip iproute2 iptables curl xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY openthread-core-config-posix.h /usr/src/
# Clone OTBR
WORKDIR /usr/src
RUN git clone https://github.com/openthread/ot-br-posix.git /usr/src/ot-br-posix
WORKDIR /usr/src/ot-br-posix
RUN git submodule update --init --recursive

RUN apt-get update && apt-get install -y sudo

RUN ./script/bootstrap
RUN apt-get purge -y libsystemd-dev

# Build OTBR (minimal)
WORKDIR /usr/src/ot-br-posix

RUN ./script/cmake-build \
    -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DOTBR_DBUS=OFF \
    -DOTBR_WEB=OFF \
    -DOTBR_REST=OFF \
    -DOT_POSIX_RCP_HDLC_BUS=ON \
    -DOTBR_BORDER_ROUTING=ON \
    -DOTBR_BACKBONE_ROUTER=ON \
    -DOTBR_NAT64=ON \
    -DOTBR_VENDOR_NAME="MyVendor" \
    -DOT_PROJECT_CONFIG="/usr/src/ot-br-posix/third_party/openthread/repo/openthread-core-config-posix.h" \
    -DOTBR_PRODUCT_NAME="ESP32-C6-RCP"

RUN cd build/otbr && ninja install

# Check results
RUN echo "==== CHECK OTBR INSTALL ====" \
 && find /usr/local -name otbr-agent || true \
 && ls -l /usr/local/bin || true

# --- Stage 2: Runtime container ---
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 libdbus-1-3 libavahi-client3 libreadline8 \
    iproute2 iptables curl ca-certificates xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install s6-overlay (v3, amd64 only)
RUN curl -L https://github.com/just-containers/s6-overlay/releases/download/v3.1.6.2/s6-overlay-noarch.tar.xz -o /tmp/s6-noarch.tar.xz \
 && curl -L https://github.com/just-containers/s6-overlay/releases/download/v3.1.6.2/s6-overlay-x86_64.tar.xz -o /tmp/s6-x86_64.tar.xz \
 && tar -C / -Jxpf /tmp/s6-noarch.tar.xz \
 && tar -C / -Jxpf /tmp/s6-x86_64.tar.xz

# Copy OTBR binaries and libraries
COPY --from=builder /usr/local/ /usr/local/

# Copy s6 service scripts
COPY rootfs/ /

# Ensure run script is executable
RUN chmod +x /etc/services.d/otbr-agent/run

# Expose optional Thread/UDP ports
EXPOSE 49191/udp

# Start s6-overlay
ENTRYPOINT ["/init"]
