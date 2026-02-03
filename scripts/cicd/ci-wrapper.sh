#!/bin/bash -e

Phase=all
Silent=false

# parse command line into arguments and check results of parsing
while getopts :dp:sw-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    d|debug)
      set -vx
      ;;
    p|phase)
      Phase=$OPTARG
      ;;
    w|windows)
      Args="--platforms=windows"
      ;;
    s|silent)
      Silent=true
      ;;
    *)
      echo "Unknown flag -$OPT given!" >&2
      exit 1
      ;;
  esac

  # Set flag to be use by Test_flag
  eval ${OPT}flag=1

done
shift $(($OPTIND -1))

repo=$(basename $PWD)

if [[ -z $GH_TOKEN ]]
then
  echo "Variable 'GH_TOKEN' not defined!" >&2
  exit 1
fi

[[ $Silent == true ]] && exec >/dev/null

case $repo in
  ansible-role-*)
    echo "Ansible role repo '$repo'"
    [[ ! -s .gitignore ]] && touch .gitignore
    sed -i -r "s|^(molecule/default/molecule.yml)$|#\\1|" .gitignore
    /opt/cicd-tools/bin/ci-init.sh $Args -m role -iF
    [[ $Phase == 1 ]] && exit 0
    /opt/cicd-tools/bin/ci-init.sh $Args -m role
    /opt/cicd-tools/bin/ansible-get-collections.sh > .collections
    ;;
  ansible-playbooks-*)
    echo "Ansible playbook repo '$repo'"
    /opt/cicd-tools/bin/ci-init.sh $Args -m playbook -iF
    [[ $Phase == 1 ]] && exit 0
    /opt/cicd-tools/bin/ci-init.sh $Args -m playbook
    ;;
  ansible-collection-*)
    echo "Ansible collection repo '$repo'"
    /opt/cicd-tools/bin/ci-init.sh $Args -m collection -iF
    [[ $Phase == 1 ]] && exit 0
    /opt/cicd-tools/bin/ci-init.sh $Args -m collection
    ;;
  *)
    echo "Unable to figure out what we are dealing with!" >&2
    exit 1
    ;;
esac

# README.md
echo "** README"
if [[ -f README.md ]] ; then
  lines=$(cat README.md | wc -l)
  if grep -q "^## Platforms" README.md ; then
    echo "Updating generic README"
    /opt/cicd-tools/bin/readme.sh
  elif [[ $lines == 1 ]]
  then
    echo "Updating generic README"
    /opt/cicd-tools/bin/readme.sh
  else
    echo "Found a custom README.md ... leaving it as it is"
  fi
else
  echo "Creating new README.md (none present)"
  /opt/cicd-tools/bin/readme.sh
fi

# Enable Github CI
set +e
gh workflow enable CI

# Exit cleanly
exit 0
