#!/bin/bash

vars="
ansible_distribution
ansible_os_family
ansible_env
"

if [[ $# -eq 0 ]]
then
  files=$(find tasks handlers defaults vars -type f)
else
  files="$@"
fi

echo "$vars" | grep -v "^$" | \
while read var
do
  var2=$(echo $var | sed "s/^ansible_/ansible_facts\./")
  for file in $files
  do
    sed -i "s/$var/$var2/g" $file
  done
done
