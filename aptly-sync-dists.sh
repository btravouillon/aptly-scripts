#!/bin/bash
# This script manages multi-component dists repositories
# See https://www.aptly.info/doc/feature/multi-component/
set -e

CONFIG=${1:-debian}
TAG=${2:-$(date +%Y%m%d%H%M)}

if [ -f "${BASH_SOURCE%/*}/config/dists/aptly-${CONFIG}.conf" ]; then
    source "${BASH_SOURCE%/*}/config/dists/aptly-${CONFIG}.conf"
else
    echo "File ${BASH_SOURCE%/*}/config/dists/aptly-${CONFIG}.conf not found."
    exit 1
fi

ENDPOINT=${ENDPOINT:-"filesystem:nightly"}

for DISTRIBUTION in ${!DISTRIBUTIONS[@]}; do
    for COMPONENT in ${DISTRIBUTIONS[$DISTRIBUTION]}; do
      if [[ -n ${PRODUCT} ]]; then
          MIRROR_NAME=${DISTRIBUTION}-${PRODUCT}-${COMPONENT}
          PREFIX="${PRODUCT}/${DISTRIBUTION}"
      else
          MIRROR_NAME=${DISTRIBUTION}-${COMPONENT}
          PREFIX="${CONFIG}"
      fi

      echo "####"
      echo "# Aptly Mirror - $DISTRIBUTION-$COMPONENT"
      echo "####"
      aptly mirror show $MIRROR_NAME >/dev/null 2>&1 || \
          aptly mirror create -filter="${FILTER}" -architectures=amd64 \
              -with-sources=${WITH_SOURCES:-true} \
              -with-udebs=${WITH_UDEBS:-true} \
              $MIRROR_NAME $MIRROR $DISTRIBUTION $COMPONENT

      echo "####"
      echo "# Aptly update - $MIRROR_NAME"
      echo "####"
      aptly mirror update $MIRROR_NAME

      echo "####"
      echo "# Aptly snapshot - $MIRROR_NAME-$TAG"
      echo "####"
      aptly snapshot create $MIRROR_NAME-$TAG from mirror $MIRROR_NAME

      # Build the list of snapshots to publish for this distribution
      SNAPSHOTS+="$MIRROR_NAME-$TAG "
    done

    echo "###"
    echo "# Aptly publish - $DISTRIBUTION"
    echo "###"
    if aptly publish show ${DISTRIBUTION} ${ENDPOINT}:${PREFIX}; then
        aptly publish switch -force-overwrite -component=${DISTRIBUTIONS[$DISTRIBUTION]// /,} \
            ${DISTRIBUTION} ${ENDPOINT}:${PREFIX} ${SNAPSHOTS}
    else
        aptly publish snapshot -component=${DISTRIBUTIONS[$DISTRIBUTION]// /,} \
            -distribution=${DISTRIBUTION} ${SNAPSHOTS} ${ENDPOINT}:${PREFIX}
    fi

    # Reset list of snapshots
    SNAPSHOTS=""
done
