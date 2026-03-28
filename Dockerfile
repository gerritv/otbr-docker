FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    lsb-release libsystemd-dev\
    libglib2.0-0 \
    dbus \
    git build-essential cmake ninja-build pkg-config \
    libssl-dev libdbus-1-dev libavahi-client-dev \
    libreadline-dev iproute2 iptables curl ca-certificates \
    python3 python3-pip \    
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/openthread/ot-br-posix.git /otbr
WORKDIR /otbr

RUN git submodule update --init --recursive

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

# s6-overlay v2 (simple + stable)
ADD https://github.com/just-containers/s6-overlay/releases/download/v2.2.0.3/s6-overlay-amd64.tar.gz /tmp/
RUN tar -C / -zxf /tmp/s6-overlay-amd64.tar.gz

# service
COPY rootfs/ /
RUN chmod +x /etc/services.d/otbr-agent/run

ENTRYPOINT ["/init"]