#!/bin/bash
# Make sure this happens before set -x
echo "$DOCKER_TOKEN" | docker login -u TOKEN --password-stdin $REGISTRY_HOST

set -x
set -e

BOLT_VERSION=`git describe`
BOLT_TAG=$REGISTRY_HOST/$DOCKER_REGISTRY/bolt-server:$BOLT_VERSION
LATEST_TAG=$REGISTRY_HOST/$DOCKER_REGISTRY/bolt-server:latest
PLAN_TAG=$REGISTRY_HOST/$DOCKER_REGISTRY/plan-executor:$BOLT_VERSION
PLAN_LATEST=$REGISTRY_HOST/$DOCKER_REGISTRY/plan-executor:latest

docker build -f Dockerfile.boltserver --tag $BOLT_TAG --tag $LATEST_TAG --build-arg bolt_version=$BOLT_VERSION ./
docker push $BOLT_TAG
docker push $LATEST_TAG

docker build -f Dockerfile.planexecutor --tag $PLAN_TAG --tag $PLAN_LATEST --build-arg bolt_version=$BOLT_VERSION ./
docker push $PLAN_TAG
docker push $PLAN_LATEST
