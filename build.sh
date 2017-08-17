#!/bin/sh
set -e

DOCKER_TAG="haproxytech/haproxy-debian"

HAPROXY_MINOR_OLD=$(awk '/^ENV HAPROXY_MINOR/ {print $NF}' Dockerfile)

./update.sh

HAPROXY_MINOR=$(awk '/^ENV HAPROXY_MINOR/ {print $NF}' Dockerfile)

if [ "x$1" != "xforce" ]; then
    if [ "x$HAPROXY_MINOR_OLD" = "x$HAPROXY_MINOR" ]; then
        echo "No new releases, not building anything."
        exit 0
    fi
fi

docker pull $(awk '/^FROM/ {print $2}' Dockerfile)
docker build -t "$DOCKER_TAG:$HAPROXY_MINOR" .
docker tag "$DOCKER_TAG:$HAPROXY_MINOR" "$DOCKER_TAG:latest"
docker push "$DOCKER_TAG"
