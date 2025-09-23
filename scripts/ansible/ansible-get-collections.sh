#!/bin/bash

TMPFILE=$(mktemp)

trap 'rm -f ${TMPFILE}*' EXIT

[[ -z $1 ]] && paths="roles playbooks tasks handlers" || paths="$@"

files=$(find $paths -type f -name \*.yml 2>/dev/null)
modules=$(yq -y . $files | grep -E "^  *[a-z0-9]*\.[a-z0-9]*\.[a-z0-9_]*:$" | sed "s/^  *//" | cut -f1-2 -d. | sort -u | grep -v ansible.builtin)

# Get collections present
if [[ -s .collections ]]
then
  yq -j . .collections > ${TMPFILE}1
else
  echo "collections: []" | yq -j . > ${TMPFILE}1
fi

# Generate new collections
if [[ -z $modules ]]
then
  echo -e "---\ncollections: []" | yq -j . > ${TMPFILE}2
else
  echo -e "---\ncollections:" >${TMPFILE}3
  echo "$modules" | sed "s/^/  - name: /" >> ${TMPFILE}3
  yq -j . ${TMPFILE}3 > ${TMPFILE}2
fi

# Merge old & new collections
echo "---"
jq -s '{collections: ( [.[].collections[]] | group_by(.name) | map(last))}' ${TMPFILE}2 ${TMPFILE}1 | \
yq -y | sed -r "s/version: (.*)/version: \"\\1\"/"
