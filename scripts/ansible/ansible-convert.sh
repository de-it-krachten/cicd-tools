#!/bin/bash

vars="
ansible_architecture
ansible_distribution
ansible_os_family
ansible_env
ansible_virtualization_type
ansible_selinux
ansible_architecture
ansible_processor
ansible_system
ansible_pkg_mgr
ansible_interfaces
ansible_default_ipv4
ansible_default_ipv6
ansible_fqdn
ansible_hostname
ansible_os_product_id
ansible_os_product_key
ansible_os_license_edition
ansible_os_license_status
ansible_processor_vcpus
ansible_memtotal_mb
ansible_all_ipv4_addresses
"

if [[ $# -eq 0 ]]
then
  files=$(find tasks handlers defaults vars templates molecule -type f 2>/dev/null)
else
  files="$@"
fi

echo "$vars" | grep -v "^$" | \
while read var
do

  var1=$(echo $var | sed "s/^ansible_/ansible_facts\./")
  for file in $files
  do
    sed -i "s/$var/$var1/g" $file
  done
done
