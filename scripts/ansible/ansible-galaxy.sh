#!/bin/bash

##############################################################
#
# Defining standard variables
#
##############################################################

# Set temporary PATH
__PYTHON_VENV=$(which python3 | sed "s|/bin/python3||")
if [[ $__PYTHON_VENV =~ ^(|/usr)$ ]]
then
  export PATH=/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH
else
  export PATH=${__PYTHON_VENV}/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH
fi
unset __PYTHON_VENV

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
# Defining standarized functions
#
#############################################################

FUNCTIONS="${DIRNAME}/functions.sh ${DIRNAME}/functions_ansible.sh"
for functions in $FUNCTIONS
do
  [[ -f ${functions} ]] && . ${functions}
done


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

   -c|--collections     : Run on collections
   -r|--roles           : Run on roles (default)
   --clean              : Delete roles before collectiong them
   -C|--clean-only      : Delete roles and does no collection

   -g|--git-source      : Skips galaxy and retrieves from github
#   -G|-no-git-ignore    : ???
   -p|--path <path>     : Target location to write roles or collections to
#   -q|--quiet           : supress common messages
   -s|--sudo            : Run using sudo

Arguments:
   \$1 : Requirements file (optional)

EOF

}

function Get_roles
{

  if [[ ! -f $Reqfile ]]
  then
    [[ $Quiet == false ]] && echo "File '$Reqfile' could not be found!" >&2
    exit ${Exit:-1}
  fi

  [[ -n $Path ]] && Args="-p ${Path}" || Args=
  [[ $Clean == true ]] && ${DIRNAME}/ansible-requirements-clean.sh ${Sudo1} ${Args} ${Clean_args} ${Reqfile}
  [[ $Clean_only == true ]] && exit 0

  $Echo ansible-galaxy install -r $Reqfile -p ${Path}roles --ignore-errors

}

function Get_collections
{

  if [[ ! -f $Reqfile ]]
  then
    [[ $Quiet == false ]] && echo "File '$Reqfile' could not be found!" >&2
    exit ${Exit:-1}
  fi

  # Use git(hub) sources instead of Galaxy
  if [[ $Git_source == true ]]
  then
    yq -y '
      .collections |= map(
        if (.name | test("^[a-z0-9_-]+\\.[a-z0-9_-]+$")) then
          .name = ("https://github.com/ansible-collections/" + .name + ".git") | .type = "git"
        else . end
      )' $Reqfile > ${TMPFILE}
    Reqfile=${TMPFILE}

    Galaxy_args="--no-deps"

  fi

  [[ $Debug == true ]] && Galaxy_args="$Galaxy_args -vvvv"
  [[ -n $Path ]] && Galaxy_args="$Galaxy_args -p ${Path}"

  $Echo ansible-galaxy collection install $Galaxy_args -r $Reqfile --ignore-errors

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

Clean_args="-v"
Quiet=false
Exit=
Mode=roles
Collections_yaml=collections/requirements.yml
Roles_yaml=roles/requirements.yml
Git_source=false

# parse command line into arguments and check results of parsing
while getopts :cCdDgGhp:qrsv-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    c|collections)
      Mode=collections
      ;;
    clean)
      Clean=true
      ;;
    C|clean-only)
      Clean=true
      Clean_only=true
      ;;
    d|debug)
      Verbose=true
      Verbose1="-v"
      Debug=true
      set -vx
      ;;
    D|dry-run)
      Dry_run=true
      Dry_run1="-D"
      Echo=echo
      ;;
    g|git-source)
      Git_source=true
      ;;
    G|no-git-ignore)
      Clean_args="${Clean_args} -G"
      ;;
    h|help)
      Usage
      exit 0
      ;;
    p|path)
      Path=$OPTARG
      ;;
    q|quiet)
      Quiet=true
      Clean_args="${Clean_args} -q"
      Exit=0
      ;;
    r|roles)
      Mode=roles
      ;;
    s|sudo)
      Sudo1="-s"
      ;;
    v|verbose)
      Verbose=true
      Verbose1="-v"
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

# For specific ansible versions, fallback onto old Galaxy
Galaxy_legacy

# Use custom path
[[ -n $Path ]] && Path="${Path}/"

case $Mode in
  roles)
    Reqfile=${1:-$Roles_yaml}
    Get_roles
    ;;
  collections)
    Reqfile=${1:-$Collections_yaml}
    Get_collections
    ;;
esac
