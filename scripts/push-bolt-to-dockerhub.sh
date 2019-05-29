#!bin/bash

# Make sure this happens before set -x
echo "${DOCKERHUB_PASS}" | docker login -u "${DOCKERHUB_USER}" --password-stdin

set -x
set -e

if [ ! -z "${TRAVIS_TAG}" ]; then
    docker build -t ${DOCKERHUB_USER}/${DOCKERHUB_REPO}:${TRAVIS_TAG} -f docker/bolt.dockerfile .
fi

# build image
docker build -t ${DOCKERHUB_USER}/${DOCKERHUB_REPO} -f docker/bolt.dockerfile .
# login to dockerhub
# push image
docker push ${DOCKERHUB_USER}/${DOCKERHUB_REPO}