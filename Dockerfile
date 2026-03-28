# --- Stage 1: Build OTBR ---
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git build-essential cmake ninja-build pkg-config \
    libssl-dev libdbus-1-dev libavahi-client-dev \
    libreadline-dev libsystemd-dev libglib2.0-0 \
    python3 python3-pip iproute2 iptables curl ca-certificates xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Clone OTBR
RUN git clone https://github.com/openthread/ot-br-posix.git /otbr
WORKDIR /otbr
RUN git submodule update --init --recursive

# Build OTBR (minimal: no tests, systemd off)
WORKDIR /otbr/build
RUN cmake -GNinja .. \
    -DOTBR_INFRA_IF_NAME=eth0 \
    -DOTBR_BORDER_ROUTING=ON \
    -DOTBR_NAT64=ON \
    -DOTBR_SYSTEMD=OFF \
    -DOTBR_BUILD_TESTS=OFF \
    -DBUILD_TESTING=OFF
RUN ninja
RUN ninja install

# --- Stage 2: Runtime container ---
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl3 libdbus-1-3 libavahi-client3 libreadline8 \
    iproute2 iptables curl ca-certificates xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install s6-overlay (amd64 only)
RUN curl -L https://github.com/just-containers/s6-overlay/releases/download/v3.1.6.2/s6-overlay-noarch.tar.xz -o /tmp/s6-noarch.tar.xz \
 && curl -L https://github.com/just-containers/s6-overlay/releases/download/v3.1.6.2/s6-overlay-x86_64.tar.xz -o /tmp/s6-x86_64.tar.xz \
 && tar -C / -Jxpf /tmp/s6-noarch.tar.xz \
 && tar -C / -Jxpf /tmp/s6-x86_64.tar.xz

# Copy built OTBR from builder
COPY --from=builder /usr/local/bin/otbr-* /usr/local/bin/
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/share /usr/local/share

# Add s6 service
COPY rootfs/ /etc/services.d/

# Ensure run script is executable
RUN chmod +x /etc/services.d/otbr-agent/run

# Expose optional Thread/UDP ports if needed
EXPOSE 49191/udp

# Start s6-overlay
ENTRYPOINT ["/init"]