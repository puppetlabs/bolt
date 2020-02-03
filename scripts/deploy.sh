#!/bin/bash
set -x
set -e

BOLT_VERSION=`git describe`
BOLT_TAG=$REGISTRY_HOST/$DOCKER_REGISTRY/bolt-server:$BOLT_VERSION
LATEST_TAG=$REGISTRY_HOST/$DOCKER_REGISTRY/bolt-server:latest

docker build --tag $BOLT_TAG --tag $LATEST_TAG --build-arg bolt_version=$BOLT_VERSION -f ./Dockerfile.bolt-server .
docker push $BOLT_TAG
docker push $LATEST_TAG
