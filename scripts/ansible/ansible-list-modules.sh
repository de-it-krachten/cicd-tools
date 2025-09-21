#!/bin/bash

# Get the name of the calling script
FILENAME=$(readlink -f $0)
BASENAME="${FILENAME##*/}"
BASENAME_ROOT=${BASENAME%%.*}
DIRNAME="${FILENAME%/*}"

case $(basename $PWD) in
  ansible-role-*)
    ANSIBLE_TYPE=role
    ;;
  ansible-playbooks-*)
    ANSIBLE_TYPE=playbooks
    ;;
  *)
    ANSIBLE_TYPE=$1
    ;;
esac

if [[ -z $ANSIBLE_TYPE ]]
then
  echo "$BASENAME <playbooks|role>" >&2
  exit 1
fi

ansible-playbook ${DIRNAME}/../ansible-list-modules/${BASENAME_ROOT}.yml -e ansible_code_path=${PWD} -e ansible_type=$ANSIBLE_TYPE
