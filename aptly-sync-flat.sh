#!/bin/bash
# This script manages flat repositories
set -e

CONFIG=${1}
TAG=${2:-$(date +%Y%m%d%H%M)}

if [ -f "${BASH_SOURCE%/*}/config/flat/aptly-${CONFIG}.conf" ]; then
    source "${BASH_SOURCE%/*}/config/flat/aptly-${CONFIG}.conf"
else
    echo "File ${BASH_SOURCE%/*}/config/flat/aptly-${CONFIG}.conf not found."
    exit 1
fi

ENDPOINT=${ENDPOINT:-"filesystem:mirror"}

for DISTRIBUTION in ${!DISTRIBUTIONS[@]}; do
    echo "####"
    echo "# Aptly Mirror - $DISTRIBUTION-$PRODUCT"
    echo "####"
    # If upstream repo uses `./` as repo directory, add the path to the mirror URI
    if [ "${REPO_DIRECTORY}" == "./" ]; then
        URI="${MIRROR}/${DISTRIBUTIONS[$DISTRIBUTION]}"
    else
        URI="${MIRROR}"
        REPO_DIRECTORY="${DISTRIBUTIONS[$DISTRIBUTION]}/"
    fi
    aptly mirror show $DISTRIBUTION-$PRODUCT >/dev/null 2>&1 || \
        aptly mirror create -filter="${FILTER}" -architectures=amd64 \
            -with-sources=${WITH_SOURCES:-true} \
            $DISTRIBUTION-$PRODUCT $URI $REPO_DIRECTORY

    echo "####"
    echo "# Aptly update - $DISTRIBUTION-$PRODUCT"
    echo "####"
    aptly mirror update $DISTRIBUTION-$PRODUCT

    echo "####"
    echo "# Aptly snapshot - $DISTRIBUTION-$PRODUCT-$TAG"
    echo "####"
    aptly snapshot create $DISTRIBUTION-$PRODUCT-$TAG from mirror $DISTRIBUTION-$PRODUCT

    echo "###"
    echo "# Aptly publish - $DISTRIBUTION-$PRODUCT"
    echo "###"
    PREFIX="${PRODUCT}/nightly/${DISTRIBUTIONS[$DISTRIBUTION]}"
    if aptly publish show $DISTRIBUTION-$PRODUCT ${ENDPOINT}:${PREFIX}; then
        aptly publish switch $DISTRIBUTION-$PRODUCT ${ENDPOINT}:${PREFIX} $DISTRIBUTION-$PRODUCT-$TAG
    else
        aptly publish snapshot -distribution=$DISTRIBUTION-$PRODUCT $DISTRIBUTION-$PRODUCT-$TAG ${ENDPOINT}:${PREFIX}
    fi
done
