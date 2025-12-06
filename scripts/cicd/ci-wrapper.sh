#!/bin/bash -e

repo=$(basename $PWD)

case $repo in
  ansible-role-*)
    echo "Ansible role repo '$repo'"
    [[ ! -s .gitignore ]] && touch .gitignore
    sed -i -r "s|^(molecule/default/molecule.yml)$|#\\1|" .gitignore
    /opt/cicd-tools/bin/ci-init.sh -m role -iF
    /opt/cicd-tools/bin/ci-init.sh -m role
    /opt/cicd-tools/bin/ansible-get-collections.sh > .collections
    /opt/cicd-tools/bin/readme.sh
    gh workflow enable CI
    ;;
  ansible-playbooks-*)
    echo "Ansible playbook repo '$repo'"
    /opt/cicd-tools/bin/ci-init.sh -m playbook -iF
    /opt/cicd-tools/bin/ci-init.sh -m playbook
    /opt/cicd-tools/bin/readme.sh
    gh workflow enable CI
    ;;
  *)
    echo "Unable to figure out what we are dealing with!" >&2
    exit 1
    ;;
esac
