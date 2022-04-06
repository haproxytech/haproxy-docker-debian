FROM debian:buster-slim AS opentracing
ENV OPENTRACING_CPP_MINOR 1.5.0
ENV OPENTRACING_C_WRAPPER_MINOR 1.1.3
ENV JAEGER_CLIENT_CPP_MINOR 0.5.0
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gcc \
    libc6-dev \
    liblua5.3-dev \
    libpcre2-dev \
    libssl-dev \
    make \
    cmake \
    build-essential \
    software-properties-common \
    wget \
    ;

RUN cd /tmp; wget https://github.com/opentracing/opentracing-cpp/archive/v$OPENTRACING_CPP_MINOR.tar.gz ; \
    tar xf v$OPENTRACING_CPP_MINOR.tar.gz; \
    cd opentracing-cpp-$OPENTRACING_CPP_MINOR; \
    mkdir build; \
    cd build; \
    cmake -DCMAKE_INSTALL_PREFIX=/opt ..; \
    make; \
    make install

RUN apt-get install -y --no-install-recommends \
    automake \
    pkg-config \
    libtool

# FIXME: We must rename the src directory or `make install` will not install it's include's properly.
# configure.ac sets the name of the library as including $PWD.
RUN cd /tmp; wget https://github.com/haproxytech/opentracing-c-wrapper/archive/refs/tags/v$OPENTRACING_C_WRAPPER_MINOR.tar.gz ; \
    tar xvf v$OPENTRACING_C_WRAPPER_MINOR.tar.gz; \
    mv opentracing-c-wrapper-${OPENTRACING_C_WRAPPER_MINOR} opentracing-c-wrapper; \
    cd opentracing-c-wrapper; \
    ./scripts/bootstrap; \
    ./configure --prefix=/opt --with-opentracing=/opt; \
    make; \
    make install

# We need the plugin.so which doesn't get installed by make.
RUN cd /tmp; wget https://github.com/jaegertracing/jaeger-client-cpp/archive/v$JAEGER_CLIENT_CPP_MINOR.tar.gz; \
    tar xf v$JAEGER_CLIENT_CPP_MINOR.tar.gz; \
    cd jaeger-client-cpp-$JAEGER_CLIENT_CPP_MINOR; \
    mkdir build; \
    cd build; \
    cmake -DCMAKE_INSTALL_PREFIX=/opt -DJAEGERTRACING_PLUGIN=ON -DHUNTER_CONFIGURATION_TYPES=Release -DHUNTER_BUILD_SHARED_LIBS=OFF ..; \
    make; \
    make install; \
    cp -v libjaegertracing_plugin.so /opt/lib

FROM golang:latest AS builder

ENV DATAPLANE_MINOR 2.5.2
ENV DATAPLANE_URL https://github.com/haproxytech/dataplaneapi.git

RUN git clone "${DATAPLANE_URL}" "${GOPATH}/src/github.com/haproxytech/dataplaneapi"
RUN cd "${GOPATH}/src/github.com/haproxytech/dataplaneapi" && \
    git checkout "v${DATAPLANE_MINOR}" && \
    make build && cp build/dataplaneapi /dataplaneapi

FROM debian:buster-slim

MAINTAINER Dinko Korunic <dkorunic@haproxy.com>

LABEL Name HAProxy
LABEL Release Community Edition
LABEL Vendor HAProxy
LABEL Version 2.4.15
LABEL RUN /usr/bin/docker -d IMAGE

ENV HAPROXY_BRANCH 2.4
ENV HAPROXY_MINOR 2.4.15
ENV HAPROXY_SHA256 3958b17b7ee80eb79712aaf24f0d83e753683104b36e282a8b3dcd2418e30082
ENV HAPROXY_SRC_URL http://www.haproxy.org/download

ENV HAPROXY_UID haproxy
ENV HAPROXY_GID haproxy

ENV DEBIAN_FRONTEND noninteractive

COPY --from=builder /dataplaneapi /usr/local/bin/dataplaneapi
COPY --from=opentracing /opt /opt
#COPY --from=opentracing /jaeger-client-cpp-$JAEGER_CLIENT_CPP_MINOR/libjaegertracing_plugin.so /usr/local/lib64

RUN apt-get update && \
    apt-get install -y --no-install-recommends procps libssl1.1 zlib1g "libpcre2-*" liblua5.3-0 libatomic1 tar curl socat ca-certificates && \
    apt-get install -y --no-install-recommends gcc make libc6-dev libssl-dev libpcre2-dev zlib1g-dev liblua5.3-dev pkg-config && \
    c_rehash && \
    curl -sfSL "${HAPROXY_SRC_URL}/${HAPROXY_BRANCH}/src/haproxy-${HAPROXY_MINOR}.tar.gz" -o haproxy.tar.gz && \
    echo "$HAPROXY_SHA256 *haproxy.tar.gz" | sha256sum -c - && \
    groupadd "$HAPROXY_GID" && \
    useradd -g "$HAPROXY_GID" "$HAPROXY_UID" && \
    mkdir -p /tmp/haproxy && \
    tar -xzf haproxy.tar.gz -C /tmp/haproxy --strip-components=1 && \
    rm -f haproxy.tar.gz && \
    PKG_CONFIG_PATH=/opt/lib/pkgconfig make -C /tmp/haproxy -j"$(nproc)" TARGET=linux-glibc CPU=generic USE_PCRE2=1 USE_PCRE2_JIT=1 USE_OPENSSL=1 \
    USE_TFO=1 USE_LINUX_TPROXY=1 USE_LUA=1 USE_GETADDRINFO=1 \
    USE_PROMEX=1 USE_SLZ=1 \
    USE_OT=1 \
    all && \
    make -C /tmp/haproxy TARGET=linux-glibc install-bin install-man && \
    ln -s /usr/local/sbin/haproxy /usr/sbin/haproxy && \
    mkdir -p /var/lib/haproxy && \
    chown "$HAPROXY_UID:$HAPROXY_GID" /var/lib/haproxy && \
    mkdir -p /usr/local/etc/haproxy && \
    ln -s /usr/local/etc/haproxy /etc/haproxy && \
    cp -R /tmp/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors && \
    rm -rf /tmp/haproxy && \
    apt-get purge -y --auto-remove gcc make libc6-dev libssl-dev libpcre2-dev zlib1g-dev liblua5.3-dev pkg-config && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    chmod +x /usr/local/bin/dataplaneapi && \
    ln -s /usr/local/bin/dataplaneapi /usr/bin/dataplaneapi && \
    touch /usr/local/etc/haproxy/dataplaneapi.hcl && \
    chown "$HAPROXY_UID:$HAPROXY_GID" /usr/local/etc/haproxy/dataplaneapi.hcl

COPY haproxy.cfg /usr/local/etc/haproxy
COPY docker-entrypoint.sh /

STOPSIGNAL SIGUSR1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
