#!/bin/bash

Customer_pwd_store=$PASSWORD_STORE_DIR_CUSTOMER
Vault=${VAULT_CREDENTIAL:-ansible-vault}
[[ $1 == -v ]] && echo $Vault

if [[ -z $PASSWORD_STORE_DIR_CUSTOMER ]]
then
  pass ls $Vault
else
  PASSWORD_STORE_DIR=$PASSWORD_STORE_DIR_CUSTOMER pass ls $Vault
fi
