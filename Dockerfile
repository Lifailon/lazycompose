FROM alpine:3.23

ARG TARGETARCH

ENV TERM=xterm-256color
ENV SHELL=/bin/bash

RUN apk add --progress --no-cache \
    util-linux \
    bash \
    curl \
    nano \
    micro \
    fzf \
    jq \
    yq-go \
    docker-cli

RUN ARCH=$(case ${TARGETARCH} in \
    "amd64") echo "x86_64" ;; \
    "arm64") echo "aarch64" ;; \
    *) echo "${TARGETARCH}" ;; \
    esac) && \
    latest=$(curl -s https://api.github.com/repos/tsl0922/ttyd/releases/latest | jq -r .tag_name) && \
    curl -sSLf "https://github.com/tsl0922/ttyd/releases/download/${latest}/ttyd.${ARCH}" -o /bin/ttyd && \
    latest=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name) && \
    curl -sSLf "https://github.com/docker/compose/releases/download/${latest}/docker-compose-linux-${ARCH}" -o /bin/docker-compose && \
    latest=$(curl -s https://api.github.com/repos/bensadeh/tailspin/releases/latest | jq -r .tag_name) && \
    curl -sSLf "https://github.com/bensadeh/tailspin/releases/download/${latest}/tailspin-${ARCH}-unknown-linux-musl.tar.gz" -o /tmp/tailspin.tar.gz && \
    tar -xzf /tmp/tailspin.tar.gz -C /bin/ tspin && rm /tmp/tailspin.tar.gz

COPY config.yml /config.yml
COPY lazycompose /lazycompose.sh

RUN chmod +x /bin/ttyd /bin/docker-compose /bin/tspin /lazycompose.sh

ENTRYPOINT ["/lazycompose.sh"]