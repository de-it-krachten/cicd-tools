#!/bin/bash

DIRNAME=`dirname $0`
VAULT=`which vault.sh`
TMPFILE=$(mktemp)

if [[ $# -lt 2 || $1 == -h ]]
then
  cat <<EOF >&2
Decrypt and show a vaulted key/value

Usage    : $0 <yaml-file> <var>
Examples : $0 group_vars/all '.weblogic_console_password'
           $0 group_vars '.users[] | select(.name == \"bas\") | .password'
EOF
  exit 1
fi

Yamlfile="$1"
Filter="$2"
if [[ $# -gt 2 ]]
then
  Rekey=true
  Key_old=$3
  Key_new=$4
fi

if [[ $Rekey == true ]]
then
  eval yq -r \"${Filter}\" $Yamlfile | \
  VAULT_CREDENTIAL=$Key_old ansible-vault decrypt --vault-password-file=$VAULT >$TMPFILE
  VAULT_CREDENTIAL=$Key_new ansible-vault encrypt_string --vault-password-file=$VAULT --encrypt-vault-id=default < $TMPFILE
  shred -n 3 -z -u $TMPFILE 
else
  if [[ -n $VAULT && -x $VAULT ]]
  then
    eval yq -r \"${Filter}\" $Yamlfile | ansible-vault decrypt --vault-password-file=$VAULT
    echo
  else
    eval yq -r \"${Filter}\" $Yamlfile | ansible-vault decrypt --ask-vault-pass 
    echo
  fi
fi
