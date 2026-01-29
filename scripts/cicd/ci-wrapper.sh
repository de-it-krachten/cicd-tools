#!/bin/bash -e

repo=$(basename $PWD)

if [[ -z $GH_TOKEN ]]
then
  echo "Variable 'GH_TOKEN' not defined!" >&2
  exit 1
fi

case $repo in
  ansible-role-*)
    echo "Ansible role repo '$repo'"
    [[ ! -s .gitignore ]] && touch .gitignore
    sed -i -r "s|^(molecule/default/molecule.yml)$|#\\1|" .gitignore
    /opt/cicd-tools/bin/ci-init.sh -m role -iF
    /opt/cicd-tools/bin/ci-init.sh -m role
    /opt/cicd-tools/bin/ansible-get-collections.sh > .collections
    /opt/cicd-tools/bin/readme.sh
    ;;
  ansible-playbooks-*)
    echo "Ansible playbook repo '$repo'"
    /opt/cicd-tools/bin/ci-init.sh -m playbook -iF
    /opt/cicd-tools/bin/ci-init.sh -m playbook
    /opt/cicd-tools/bin/readme.sh
    ;;
  ansible-collection-*)
    echo "Ansible collection repo '$repo'"
    /opt/cicd-tools/bin/ci-init.sh -m collection -iF
    /opt/cicd-tools/bin/ci-init.sh -m collection
    /opt/cicd-tools/bin/readme.sh
    ;;
  *)
    echo "Unable to figure out what we are dealing with!" >&2
    exit 1
    ;;
esac

# Enable Github CI
set +e
gh workflow enable CI

# Exit cleanly
exit 0
