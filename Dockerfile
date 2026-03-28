FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    lsb-release \
    git build-essential cmake ninja-build pkg-config \
    libssl-dev libdbus-1-dev libavahi-client-dev \
    libreadline-dev iproute2 iptables curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/openthread/ot-br-posix.git /otbr
WORKDIR /otbr

RUN ./script/bootstrap
RUN INFRA_IF_NAME=eth0 ./script/setup

# s6-overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v3.1.6.2/s6-overlay-noarch.tar.xz /tmp/
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz

# service
COPY rootfs/ /

ENTRYPOINT ["/init"]