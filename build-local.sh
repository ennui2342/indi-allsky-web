#!/bin/bash
# Build indi-allsky-web:local on this machine exactly as CI does: upstream's
# Dockerfile.gunicorn at UPSTREAM_REF, then this repo's Dockerfile on top.
set -o errexit
set -o nounset

cd "$(dirname "$0")"
ref=$(tr -d '[:space:]' < UPSTREAM_REF)

if [ ! -d upstream/.git ]; then
    git clone --quiet https://github.com/aaronwmorris/indi-allsky.git upstream
fi
git -C upstream fetch --quiet --depth 1 origin "$ref"
git -C upstream checkout --quiet --force "$ref"
# The image's COPY keeps file modes and runs pip as a non-root user, so a
# restrictive umask (077) breaks the build; CI's runners use 022.
chmod -R a+rX upstream

docker build -f upstream/docker/Dockerfile.gunicorn --build-arg TZ=Europe/London \
    -t indi-allsky-gunicorn:base upstream
docker build --build-arg BASE_IMAGE=indi-allsky-gunicorn:base -t indi-allsky-web:local .
echo "built indi-allsky-web:local from indi-allsky $ref"
