#!/bin/bash

set -e

here=$(dirname $(realpath "$0" 2> /dev/null || grealpath "$0"))
test -n "$here" -a -d "$here" || (echo "Cannot determine build dir. FIXME!" && exit 1)
. "$here"/../base.sh # functions we use below (fail, et al)

if [ -z "$1" ]; then
    fail "Please specify a release tag or branch to build (eg: master or 4.0.0, etc)"
fi

REV="$1"
PROJECTDIR="$here"/../..
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
    fail "Docker is required to build for Windows"
fi

info "Using docker: $docker_version"

SUDO=""  # on macOS (and others?) we don't do sudo for the docker commands ...
if [ $(uname) = "Linux" ]; then
    # .. on Linux we do
    SUDO="sudo"
fi

info "Creating docker image ..."
$SUDO docker build -t electroncash-wine-builder-img "$here"/docker \
    || fail "Failed to create docker image"

# This is the place where we checkout and put the exact revision we want to work
# on. Docker will run mapping this directory to /opt/wine64/drive_c/electroncash
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
    --name electroncash-wine-builder-cont \
    -v "$FRESH_CLONE_DIR":/opt/wine64/drive_c/electroncash \
    -v "$CACHE_DIR":/opt/wine64/drive_c/electroncash/contrib/build-wine/.cache \
    --rm \
    --workdir /opt/wine64/drive_c/electroncash/contrib/build-wine \
    electroncash-wine-builder-img \
    ./_build.sh
) || fail "Build inside docker container failed"

info "Copying .exe files out of our build directory ..."
mkdir -p "$OUTDIR"
files=$FRESH_CLONE_DIR/contrib/build-wine/dist/*.exe
for f in $files; do
    bn=`basename $f`
    cp -fpv $f "$OUTDIR"/$bn || fail "Failed to copy $bn"
    touch "$OUTDIR"/$bn || fail "Failed to update timestamp on $bn"
done

info "Removing $FRESH_CLONE_DIR ..."
$SUDO rm -fr "$FRESH_CLONE_DIR"

echo ""
info "Done. Built .exe files have been placed in dist/"
