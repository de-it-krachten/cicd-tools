#!/bin/bash

prefix=/opt/cicd-tools

# Check if sudo should be used
[[ $(id -un) != root ]] && sudo=sudo

# Use a custom prefix
[[ $1 == --prefix ]] && prefix=$2 && shift 2

# Copy files
if [[ $(which rsync 2>/dev/null) != "" ]]
then
  $sudo rsync $rsync_args -av scripts/* ${prefix}/ | grep -v "/$"
else
  $sudo cp -pr scripts/* ${prefix}/
fi

# Create symlinks
for f in /opt/cicd-tools/bin/*
do
  $sudo ln -fs $f /usr/local/bin/$(basename $f)
done

# Fix ownership
$sudo chown -h -R root:root ${prefix}
