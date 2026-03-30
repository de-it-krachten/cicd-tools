#!/bin/bash

# iamge1 = parent image
# image2 = intermediate image (before ansible)
# image3 = final image (after ansible)

exec >/tmp/docker-squash.log 2>&1
set -vx

if [[ $# -ne 3 ]]
then
  echo "Usage : $0 <parent-image> <intermediate-image> <final-image>" >&2
  exit 1
fi

image1=$1
image2=$2
image3=$3

layers1=$(docker history $image1 | wc -l)
layers2=$(docker history $image2 | wc -l)

# Get all layers since
layers2squash=$(( $layers2 - $layers1 ))

/usr/local/bin/docker-squash \
  --from-layer $layers2squash \
  --tag $image3 \
  --message "Used docker-squash for squashing all layers since parent" \
  $image2
