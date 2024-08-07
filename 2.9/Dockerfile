FROM golang:alpine3.20 AS builder

ENV DATAPLANE_MINOR 2.9.6
ENV DATAPLANE_URL https://github.com/haproxytech/dataplaneapi.git

RUN apk add --no-cache ca-certificates git make && \
    git clone "${DATAPLANE_URL}" "${GOPATH}/src/github.com/haproxytech/dataplaneapi" && \
    cd "${GOPATH}/src/github.com/haproxytech/dataplaneapi" && \
    git checkout "v${DATAPLANE_MINOR}" && \
    make build && cp build/dataplaneapi /dataplaneapi

FROM debian:bookworm-slim

MAINTAINER Dinko Korunic <dkorunic@haproxy.com>

LABEL Name HAProxy
LABEL Release Community Edition
LABEL Vendor HAProxy
LABEL Version 2.9.9
LABEL RUN /usr/bin/docker -d IMAGE

ENV HAPROXY_BRANCH 2.9
ENV HAPROXY_MINOR 2.9.9
ENV HAPROXY_SHA256 fa745236898549103e47799067cbc60de7ab78402484ba002ed56b05a0f93b5e
ENV HAPROXY_SRC_URL http://www.haproxy.org/download

ENV HAPROXY_UID haproxy
ENV HAPROXY_GID haproxy

ENV DEBIAN_FRONTEND noninteractive

COPY --from=builder /dataplaneapi /usr/local/bin/dataplaneapi

RUN apt-get update && \
    apt-get install -y --no-install-recommends procps libssl3 zlib1g "libpcre2-*" liblua5.4-0 libatomic1 tar curl socat ca-certificates libjemalloc2 && \
    apt-get install -y --no-install-recommends gcc make libc6-dev libssl-dev libpcre2-dev zlib1g-dev liblua5.4-dev libjemalloc-dev && \
    c_rehash && \
    curl -sfSL "${HAPROXY_SRC_URL}/${HAPROXY_BRANCH}/src/haproxy-${HAPROXY_MINOR}.tar.gz" -o haproxy.tar.gz && \
    echo "$HAPROXY_SHA256 *haproxy.tar.gz" | sha256sum -c - && \
    groupadd "$HAPROXY_GID" && \
    useradd -g "$HAPROXY_GID" "$HAPROXY_UID" && \
    mkdir -p /tmp/haproxy && \
    tar -xzf haproxy.tar.gz -C /tmp/haproxy --strip-components=1 && \
    rm -f haproxy.tar.gz && \
    make -C /tmp/haproxy -j"$(nproc)" TARGET=linux-glibc CPU=generic USE_PCRE2=1 USE_PCRE2_JIT=1 \
                            USE_TFO=1 USE_LINUX_TPROXY=1 USE_LUA=1 USE_GETADDRINFO=1 \
                            USE_PROMEX=1 USE_SLZ=1 \
                            USE_OPENSSL=1 USE_PTHREAD_EMULATION=1 \
                            USE_QUIC=1 USE_QUIC_OPENSSL_COMPAT=1 \
                            ADDLIB=-ljemalloc \
                            all && \
    make -C /tmp/haproxy TARGET=linux-glibc install-bin install-man && \
    ln -s /usr/local/sbin/haproxy /usr/sbin/haproxy && \
    mkdir -p /var/lib/haproxy && \
    chown "$HAPROXY_UID:$HAPROXY_GID" /var/lib/haproxy && \
    mkdir -p /usr/local/etc/haproxy && \
    ln -s /usr/local/etc/haproxy /etc/haproxy && \
    cp -R /tmp/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors && \
    rm -rf /tmp/haproxy && \
    apt-get purge -y --auto-remove gcc make libc6-dev libssl-dev libpcre2-dev zlib1g-dev liblua5.4-dev libjemalloc-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    chmod +x /usr/local/bin/dataplaneapi && \
    ln -s /usr/local/bin/dataplaneapi /usr/bin/dataplaneapi && \
    touch /usr/local/etc/haproxy/dataplaneapi.yml && \
    chown "$HAPROXY_UID:$HAPROXY_GID" /usr/local/etc/haproxy/dataplaneapi.yml

COPY haproxy.cfg /usr/local/etc/haproxy
COPY docker-entrypoint.sh /

STOPSIGNAL SIGUSR1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
