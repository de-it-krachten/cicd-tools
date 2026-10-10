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
# Defining standardized functions
#
#############################################################

#FUNCTIONS=${DIRNAME}/functions.sh
#for Function in $FUNCTIONS
#do
#  if [[ -f ${Function} ]]
#  then
#    . ${Function}
#  else
#    echo "Functions file '${Function}' could not be found!" >&2
#    exit 1
#  fi
#done


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

function Cancel
{

  # Cancel runs
  runs=$(gh run list --repo "$Org/$Repo" --json name,status,databaseId --limit 1000 | jq '.[] | select(.status=="queued") | .databaseId')

  count=$(echo "$runs" | wc -l)
  count=$(($count - 1))
  counter=0

  for run in $runs
  do
    counter=$(($counter+1))
    echo "[$counter/$count] Deleting '$run'"
    gh run cancel --repo "$Org/$Repo" $run >/dev/null
    sleep 1
  done

}

function Delete
{

  # Delete runs
  Cutoff=$(date -d "$Days days ago" +%Y-%m-%d)
  runs=$(gh run list --repo "$Org/$Repo" --created "<${Cutoff}" --limit 1000 --json databaseId | jq '.[].databaseId')

  count=$(echo "$runs" | wc -l)
  count=$(($count - 1))
  counter=0

  for run in $runs
  do
    counter=$(($counter+1))
    echo "[$counter/$count] Deleting '$run'"
    gh run delete --repo "$Org/$Repo" $run >/dev/null
    sleep 1
  done

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

Cancel=false
Delete=false
Maxdays=90

# parse command line into arguments and check results of parsing
while getopts :cdDhm:vx-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    c|cancel)
      Cancel=true
      ;;
    d|debug)
      Verbose=true
      Verbose1="-v"
      set -vx
      ;;
    D|dry-run)
      Dry_run=true
      Dry_run1="-D"
      Echo=echo
      ;;
    h|help)
      Usage
      exit 0
      ;;
    m|max-days)
      Maxdays=$OPTARG
      ;;
    v|verbose)
      Verbose=true
      Verbose1="-v"
      ;;
    x|delete)
      Delete=true
      ;;
    *)
      echo "Unknown flag -$OPT given!" >&2
      exit 1
      ;;
  esac

done
shift $(($OPTIND -1))

if [[ $# -lt 2 ]]
then
  echo "Usage : $0 <org> <repo|ALL>" >&2
  exit 1
fi

Org="$1"
shift
Repos="$@"

if [[ $Repos == ALL ]]
then
  echo "Fetching all repositories in organization: $Org"
  Repos=$(gh repo list $Org --json name --jq ".[].name" --limit 1000 | sort)
else
  Repos=$(ls -d "$@" | xargs -n1 echo)
fi

echo "$Repos" | while read Repo
do

  echo "=== Processing $Repo ==="

  [[ $Cancel == true ]] && Cancel
  [[ $Delete == true ]] && Delete

done
