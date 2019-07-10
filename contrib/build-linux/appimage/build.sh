#!/bin/bash

set -e

here=$(dirname $(realpath "$0" 2> /dev/null || grealpath "$0"))
test -n "$here" -a -d "$here" || (echo "Cannot determine build dir. FIXME!" && exit 1)
. "$here"/../../base.sh # functions we use below (fail, et al)

if [ -z "$1" ]; then
    fail "Please specify a release tag or branch to build (eg: master or 4.0.0, etc)"
fi

REV="$1"
PROJECTDIR="$here"/../../..
OUTDIR="$PROJECTDIR"/dist

docker_version=`docker --version`

if [ "$?" != 0 ]; then
    echo ''
    echo "Please install docker by issuing the following commands (assuming you are on Ubuntu):"
    echo ''
    echo '$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -'
    echo '$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"'
    echo '$ sudo apt-get update'
    echo '$ sudo apt-get install -y docker-ce'
    echo ''
    fail "Docker is required to build for Linux"
fi

info "Using docker: $docker_version"

SUDO=""  # on macOS (and others?) we don't do sudo for the docker commands ...
if [ $(uname) = "Linux" ]; then
    # .. on Linux we do
    SUDO="sudo"
fi

# Ubuntu 18.04 based docker file. Seems to have trouble on older systems
# due to incompatible GLIBC and other libs being too new inside the squashfs.
# BUT it has OpenSSL 1.1.  We will switch to this one sometime in the future
# "when the time is ripe".
#DOCKER_SUFFIX=ub1804
# Ubuntu 16.04 based docker file. Works on a wide variety of older and newer
# systems but only has OpenSSL 1.0. We will use this one for now until
# the world upgrades -- and since OpenSSL 1.1 isn't a hard requirement
# for us, we'll live.  (Note that it's also possible to build our own OpenSSL
# in the docker image if we get desperate for OpenSSL 1.1 but still want to
# benefit from the compatibility granted to us by using an older Ubuntu).
DOCKER_SUFFIX=ub1604

info "Creating docker image ..."
$SUDO docker build -t electroncash-appimage-builder-img-$DOCKER_SUFFIX \
    -f "$here"/Dockerfile_$DOCKER_SUFFIX \
    "$here" \
    || fail "Failed to create docker image"

# This is the place where we checkout and put the exact revision we want to work
# on. Docker will run mapping this directory to /opt/electroncash
# which inside wine will look like c:\electroncash
FRESH_CLONE_DIR="$here"/fresh_clone

(
    $SUDO rm -fr "$FRESH_CLONE_DIR"
    git clone --reference "$PROJECTDIR" --dissociate "$GIT_REPO" "$FRESH_CLONE_DIR"
    cd "$FRESH_CLONE_DIR"
    git checkout -b build "$REV"
    git submodule init
    git config --file .gitmodules --get-regexp path | awk '{ print $2 }' | while read submodule ; do
        git submodule update --dissociate --reference "$PROJECTDIR"/.git/modules/$submodule $submodule
    done
) || fail "Could not create a fresh clone from git"

CACHE_DIR="$here"/.cache

info "Starting docker container ..."

(
    mkdir -p "$CACHE_DIR" || true
    # NOTE: We propagate forward the GIT_REPO override to the container's env,
    # just in case it needs to see it.
    $SUDO docker run -it \
    -e GIT_REPO="$GIT_REPO" \
    --name electroncash-appimage-builder-cont-$DOCKER_SUFFIX \
    -v "$FRESH_CLONE_DIR":/opt/electroncash \
    -v "$CACHE_DIR":/opt/electroncash/contrib/build-linux/appimage/.cache \
    --rm \
    --workdir /opt/electroncash/contrib/build-linux/appimage \
    electroncash-appimage-builder-img-$DOCKER_SUFFIX \
    ./_build.sh
) || fail "Build inside docker container failed"

info "Copying built files out of working clone..."
mkdir -p "$OUTDIR"
cp -fpvR $FRESH_CLONE_DIR/dist/* "$OUTDIR"/ || fail "Could not copy files"

info "Removing $FRESH_CLONE_DIR ..."
$SUDO rm -fr "$FRESH_CLONE_DIR"

echo ""
info "Done. Built AppImage has been placed in $OUTDIR"
