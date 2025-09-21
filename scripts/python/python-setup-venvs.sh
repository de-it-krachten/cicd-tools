#!/bin/bash

PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH
BASENAME=$(basename $(readlink -f $0))
DIRNAME=$(dirname $(readlink -f $0))
BASENAME_ROOT=${BASENAME%%.*}
HOSTNAME=$(hostname -f)
TMPFILE=$(mktemp)

function Print_separator
{
  printf "%80s\n" | tr ' ' '-'
}

[[ $1 == --sudo ]] && sudo=sudo && shift

root_dir=$1

if [[ -z $root_dir ]]
then
  echo "Usage   : $0 <proot-dir>" >&2
  echo "Example : $0 /data/venv" >&2
  exit 1
fi

# Setup ansible
for venv in yq e2j2 ansible9 ansible12 ansiblecore216 ansiblecore219
do
  Print_separator
  echo "$venv"
  Print_separator
  $sudo ${DIRNAME}/python.sh -c ${DIRNAME}/ansible.yml -p $venv -V $root_dir/$venv
done
