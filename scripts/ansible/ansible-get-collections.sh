#!/bin/bash

[[ -z $1 ]] && paths="roles playbooks tasks handlers" || paths="$@"

files=$(find $paths -type f -name \*.yml 2>/dev/null)
modules=$(yq -y . $files | grep -E "^  *[a-z0-9]*\.[a-z0-9]*\.[a-z0-9_]*:$" | sed "s/^  *//" | cut -f1-2 -d. | sort -u | grep -v ansible.builtin)

if [[ -z $modules ]]
then
  echo -e "---\ncollections: []"
else
  echo -e "---\ncollections:"
  echo "$modules" | sed "s/^/  - name: /"
fi
