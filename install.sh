#!/bin/bash

[[ $(id -un) != root ]] && sudo=sudo

prefix=/opt/cicd-tools
[[ $1 == --prefix ]] && prefix=$2 && shift 2

$sudo cp -pr scripts/* ${prefix}/
for f in /opt/cicd-tools/bin/*
do
  $sudo ln -fs $f /usr/local/bin/$(basename $f)
done
$sudo chown -h -R root:root ${prefix}
