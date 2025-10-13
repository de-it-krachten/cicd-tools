#!/bin/bash -e

case $(basename $PWD) in
  ansible-role-*)
    sed -i -r "s|^(molecule/default/molecule.yml)$|#\\1|" .gitignore
    /opt/cicd-tools/bin/ci-init.sh -m role -iF
    /opt/cicd-tools/bin/ci-init.sh -m role
    /opt/cicd-tools/bin/ansible-get-collections.sh > .collections
    /opt/cicd-tools/bin/readme.sh
    gh workflow enable CI
    ;;
  ansible-playbooks-*)
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
