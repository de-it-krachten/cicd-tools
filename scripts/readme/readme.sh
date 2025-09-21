#!/bin/bash -e

# Get the name of the calling script
FILENAME=$(readlink -f $0)
BASENAME="${FILENAME##*/}"
BASENAME_ROOT=${BASENAME%%.*}
DIRNAME="${FILENAME%/*}"
TMPDIR=$(mktemp -d)
BINDIR=$(readlink -f $DIRNAME/../bin)
export TMPDIR BINDIR

trap 'rm -fr ${TMPDIR}' EXIT

file=${1:-'README.md'}

# Get role name from current directory
Bin_dir=$DIRNAME
Working_dir=$PWD
Name=$(basename $Working_dir)

case $Name in
  ansible-role-*)
    Type=role
    ;;
  ansible-playbooks-*)
    Type=playbooks
    ;;
  ansible-collection-*)
    Type=collection
    ;;
  *)
    echo "Unable to find out repo type" >&2
    exit 1
    ;;
esac
    
ansible-playbook $DIRNAME/readme-$Type.yml -e name=$Name -e working_dir=$Working_dir -e readme_file=$file
