#!/bin/bash
#
#=====================================================================
#
# Name        :
# Version     :
# Author      :
# Description :
#
#
#=====================================================================
unset Debug
#export Debug="set -x"
$Debug


##############################################################
#
# Defining standard variables
#
##############################################################

# Set temporary PATH
export PATH=/bin:/usr/bin:/sbin:/usr/sbin:$PATH

# Get the name of the calling script
FILENAME=$(readlink -f $0)
BASENAME="${FILENAME##*/}"
BASENAME1="${0##*/}"
BASENAME_ROOT=${BASENAME%%.*}
DIRNAME="${FILENAME%/*}"

# Define temorary files, debug direcotory, config and lock file
TMPDIR=/tmp
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

CUSTOMER=${CICD_ORGANIZATION:-'ditk'}


##############################################################
#
# Defining standarized functions
#
#############################################################

FUNCTIONS=${DIRNAME}/functions.sh
if [[ -f ${FUNCTIONS} ]]
then
   . ${FUNCTIONS}
#else
#   echo "Functions file '${FUNCTIONS}' could not be found!" >&2
#   exit 1
fi


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

   -d|--debug         : Debug mode (set -x)
   -D|--dry-run       : Dry run mode
   -h|--help          : Prints this help message
   -v|--verbose       : Verbose output

   -c|--customer      : Customers (ditk, ga etc)
#   -f|--fedora        : Support Fedora
   -F|--force         : Force updating existing files
   -i|--initialize    : Initialize repository
   -p|--platforms <f> : Platforms template (default=default)
                        Chhose from: default, docker, no-ci, windows
   -m|--mode <mode>   : Mode to operate in (collection/role/playbook)
   -s|--self-hosted   : Use self-hosted runners
   -u|--upload        : Upload collection to galaxy

EOF

}

function Executable_test
{

  Executable=$1
  Exec=`which $Executable 2>/dev/null`

  if [[ -z $Exec ]]
  then
    echo "$Executable not found!" >&2
    echo "You might have to switch to a(nother) virtualenv" >&2
    exit 1
  fi

}

function Format_yaml
{

  yq -y . $1 > /tmp/`basename $1`
  Header=$(head -1 /tmp/`basename $1`)
  [[ $Header != "---" ]] && echo -e "---\n" > $1
  cat /tmp/`basename $1` >> $1

}

function Update_from_template
{

  Source=$1
  Target=$2

  rm -f /tmp/${Source}*

  if [[ -f ${Target} ]]
  then
    echo "File '${Target}' present .. project already initialized" >&2
    echo "Use the '-F' flag to force re-initialization" >&2
    exit 1
  fi

  cp ${DIRNAME}/common/*.j2 /tmp
  cp ${DIRNAME}/${Template}/${Source}.j2 /tmp

  if e2j2 -f /tmp/${Source}.j2
  then
    cp /tmp/${Source} ${Target}
  else
    echo "Error occurred!" >&2
    exit 1
  fi

}


##############################################################
#
# Main programs
#
#############################################################

# Make sure temporary files are cleaned at exit
trap 'rm -f ${TMPFILE}*' EXIT
trap 'exit 1' HUP QUIT KILL TERM INT

# Set the defaults
Debug_level=0
Verbose=false
Verbose_level=0
Dry_run=false
Echo=

Dry_run=false
Github_self_hosted=false
Initialize=false
Fedora=false

Collection_upload=false
Platforms=default
export Platforms

# parse command line into arguments and check results of parsing
while getopts :c:dDfFhim:p:suv-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    c|customer)
      Customer=$OPTARG
      ;;
    d|debug)
      Verbose=true
      Verbose_level=2
      Verbose1="-v"
      Debug_level=$(( $Debug_level + 1 ))
      export Debug="set -vx"
      $Debug
      eval Debug${Debug_level}=\"set -vx\"
      ;;
    D|dry-run)
      Dry_run=true
      Dry_run1="-D"
      Echo=echo
      ;;
    f|fedora)
      Fedora=true
      ;;
    F|force)
      Force=true
      ;;
    h|help)
      Usage
      exit 0
      ;;
    i|initialize)
      Initialize=true
      ;;
    m|mode)
      Mode=$OPTARG
      ;;
    p|platforms)
      Platforms=$OPTARG
      ;;
    s|self-hosted)
      Github_self_hosted=true
      ;;
    u|upload)
      Collection_upload=true
      ;;
    v|verbose)
      Verbose=true
      Verbose_level=$(($Verbose_level+1))
      Verbose1="$Verbose1 -v"
      ;;
    docker)
      export docker=true
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

# Perform mode to operate in based on execution scriptname
if [[ -z $Mode ]]
then
  case $BASENAME1 in
    ci-init-ansible-collection.sh)
      Mode=collection
      ;;
    ci-init-ansible-role.sh)
      Mode=role
      ;;
    ci-init-ansible-playbooks.sh)
      Mode=playbook
      ;;
  esac
fi

# Set mode-specific settings
case $Mode in
  collection)
    Template=ansible-collection
    Name=$(basename $PWD)
    Name_short=$(echo $Name | sed "s/${Template}-//")
    Collection=$Name
    Collection_short=$Name_short
    export Name Name_short Collection Collection_short
    ;;
  role)
    Template=ansible-role
    Name=$(basename $PWD)
    Name_short=$(echo $Name | sed "s/${Template}-//")
    Role=$Name
    Role_short=$Name_short
    export Name Name_short Role Role_short 
    ;;
  playbook)
    Template=ansible-playbooks
    Name=$(basename $PWD)
    Name_short=$(echo $Name | sed "s/${Template}-//")
    Playbook=$Name
    Playbook_short=$Name_short
    export Name Name_short Playbook Playbook_short
    ;;
  package)
    Template=package
    package_name=$(basename $PWD)
    package_repo=$(basename $PWD)
    package_owner=de-it-krachten
    package_maintainer="De IT Krachten B.V. <github@de-it-krachten.nl>"
    package_prefix="/usr/local/bin"
    export package_name package_repo package_owner package_maintainer package_prefix
    ;;
  '')
    echo "No mode provided!" >&2
    exit 1
    ;;
  *)
    echo "Unsupported mode '$Mode' provided!" >&2
    exit 1
    ;;
esac

Customer=${Customer:-$CUSTOMER}

echo "Settings:"
echo "==================================="
echo "Mode   : $Mode"
echo "Fedora : $Fedora"

# Delete .cicd file in forced initialization
[[ $Initialize == true && $Force == true ]] && rm -f .cicd

# Initialize repo with CI/CD config
if [[ $Initialize == true ]]
then
  export fedora=$Fedora
  Update_from_template cicd-${Customer}.yml .cicd
  [[ ! -f .cicd.overwrite ]] && Update_from_template cicd.overwrite.yml .cicd.overwrite
  exit 0
fi

# Make sure the project/repo is initialized
if [[ ! -f .cicd ]]
then
  echo "Project not initialized!" >&2
  echo "First execute '$BASENAME -i'" >&2
  exit 1
fi

# Test for all needed executables
Executable_test ansible
Executable_test ansible-playbook
Executable_test molecule

# Test if separate role dir or monolith repo
[[ $Dry_run == true ]] && Args="-CD"
case $Mode in
  playbook)
    ansible-playbook ${DIRNAME}/${Template}/ci-init.yml \
    -e playbook=$Playbook \
    -e playbook_path="$PWD" \
    -e template=$Template $Args || exit 1
    ;;
  role)
    ansible-playbook $Verbose1 ${DIRNAME}/${Template}/ci-init.yml \
    -e role=$Role \
    -e role_dir="$PWD" \
    -e template=$Template \
    -e fedora=$Fedora $Args || exit 1
    Format_yaml meta/main.yml
    ;;
  collection)
    ansible-playbook $Verbose1 ${DIRNAME}/${Template}/ci-init.yml \
    -e collection=$Collection \
    -e collection_dir="$PWD" \
    -e collection_upload=$Collection_upload \
    -e template=$Template \
    -e fedora=$Fedora $Args || exit 1
    ;;
  package)
    ansible-playbook $Verbose1 ${DIRNAME}/${Template}/ci-init.yml \
    -e collection=$Collection \
    -e collection_dir="$PWD" \
    -e collection_upload=$Collection_upload \
    -e template=$Template \
    -e fedora=$Fedora $Args || exit 1
    ;;
esac
