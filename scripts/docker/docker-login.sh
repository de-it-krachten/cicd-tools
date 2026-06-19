#!/bin/bash

[[ $1 == --podman ]] && docker=podman || docker=docker

docker_user=$(pass ls docker-hub | awk '/username:/ {print $2}')
docker_pass=$(pass ls docker-hub | awk '/token:/ {print $2}')

$docker login -u $docker_user -p $docker_pass
