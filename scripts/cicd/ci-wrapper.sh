#!/bin/bash

##############################################################
#
# Defining standard variables
#
##############################################################

# Set temporary PATH
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH

# Get the name of the calling script
FILENAME=$(readlink -f $0)
BASENAME="${FILENAME##*/}"
BASENAME_ROOT=${BASENAME%%.*}
DIRNAME="${FILENAME%/*}"

# Get name of symlink used to execute
FILENAME1=$(realpath -s $0)
BASENAME1="${FILENAME1##*/}"
BASENAME1_ROOT=${BASENAME1%%.*}
DIRNAME1="${FILENAME1%/*}"

# Define temorary files, debug direcotory, config and lock file
TMPDIR=$(mktemp -d)
VARTMPDIR=/var/tmp
TMPFILE=${TMPDIR}/${BASENAME}.${RANDOM}.${RANDOM}
DEBUGDIR=${TMPDIR}/${BASENAME_ROOT}_${USER}
CONFIGFILE=${DIRNAME}/${BASENAME_ROOT}.cfg
LOCKFILE=${VARTMP}/${BASENAME_ROOT}.lck

# Logfile & directory
LOGDIR=$DIRNAME
LOGFILE=${LOGDIR}/${BASENAME_ROOT}.log

# Set date/time related variables
DATESTAMP=$(date "+%Y%m%d")
TIMESTAMP=$(date "+%Y%m%d.%H%M%S")

# Figure out the platform
OS=$(uname -s)

# Get the hostname
HOSTNAME=$(hostname -s)


##############################################################
#
# Defining custom variables
#
##############################################################


##############################################################
#
# Defining standardized functions
#
#############################################################

# FUNCTIONS=${DIRNAME}/functions.sh
# if [[ -f ${FUNCTIONS} ]]
# then
#    . ${FUNCTIONS}
# else
#    echo "Functions file '${FUNCTIONS}' could not be found!" >&2
#    exit 1
# fi


##############################################################
#
# Defining customized functions
#
#############################################################

function Usage
{

  cat << EOF | grep -v "^#"

$BASENAME

Usage : $BASENAME <flags> <arguments>

Flags :

   -d|--debug           : Debug mode (set -x)
   -D|--dry-run         : Dry run mode
   -h|--help            : Prints this help message
   -v|--verbose         : Verbose output

EOF

}

function Readme
{

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
      echo "Renaming custom README.md -> README-original.md"
      mv README.md README-original.md
      /opt/cicd-tools/bin/readme.sh
    fi
  else
    echo "Creating new README.md (none present)"
    /opt/cicd-tools/bin/readme.sh
  fi

}

##############################################################
#
# Main programs
#
#############################################################

# Make sure temporary files are cleaned at exit
trap 'rm -fr ${TMPDIR}' EXIT
trap 'exit 1' HUP QUIT KILL TERM INT

# Set the defaults
Debug_level=0
Verbose=false
Verbose_level=0
Dry_run=false
Echo=

Phase=all
Silent=false

Platforms=${CICD_ORGANIZATION}

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
    h|help)
      Usage
      exit 0
      ;;
    p|phase)
      Phase=$OPTARG
      ;;
    w|windows)
      Platforms=windows
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
  # eval ${OPT}flag=1

done
shift $(($OPTIND -1))

repo=$(basename $PWD)

if [[ -z $GH_TOKEN ]]
then
  echo "Variable 'GH_TOKEN' not defined!" >&2
  exit 1
fi

[[ $Silent == true ]] && exec >/dev/null

Args="--platforms=$Platforms"

case $repo in
  ansible-role-*)

    /opt/cicd-tools/bin/ansible-get-collections.sh > .collections1
    cp .collections1 .collections
    rm -f .collections1
    echo "Ansible role repo '$repo'"
    [[ ! -s .gitignore ]] && touch .gitignore
    sed -i -r "s|^(molecule/default/molecule.yml)$|#\\1|" .gitignore

    # Create support snapshot @start
    [[ ! -s .snapshot1 ]] && ${DIRNAME}/ci-platform-support.sh --snapshot > .snapshot1

    # Update .cicd file
    /opt/cicd-tools/bin/ci-init.sh $Args -m role -iF
    [[ $Phase == 1 ]] && exit 0

    # Update .cicd.overwrite file
    ${DIRNAME}/ci-platform-support.sh --cicd-overwrite 

    # Update all CI code
    /opt/cicd-tools/bin/ci-init.sh $Args -m role

    # Create support snapshot @end
    ${DIRNAME}/ci-platform-support.sh --snapshot > .snapshot2

    # Update README
    Readme

    # Commit all support changes
    ${DIRNAME}/ci-platform-support.sh --commit

    ;;
  ansible-playbooks-*)
    echo "Ansible playbook repo '$repo'"
    /opt/cicd-tools/bin/ci-init.sh $Args -m playbook -iF
    [[ $Phase == 1 ]] && exit 0
    /opt/cicd-tools/bin/ci-init.sh $Args -m playbook
    Readme
    ;;
  ansible-collection-*)
    echo "Ansible collection repo '$repo'"
    /opt/cicd-tools/bin/ci-init.sh $Args -m collection -iF
    [[ $Phase == 1 ]] && exit 0
    /opt/cicd-tools/bin/ci-init.sh $Args -m collection
    Readme
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
