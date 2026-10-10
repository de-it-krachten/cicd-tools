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

$BASENAME - deep sort JSON/YAML: object keys and arrays at every level.
Arrays: objects with a "name" field first (sorted by name), then the rest by value.
 
Usage : $BASENAME <flags> <arguments>

Flags :

   -d|--debug         : Debug mode (set -x)
   -D|--dry-run       : Dry run mode
   -h|--help          : Prints this help message
   -v|--verbose       : Verbose output

   -j|--json          : Output as json (default)
   -s|--selftest      : Executes a selftest
   -y|--yaml          : Output as yaml

EOF

}

function Selftest
{

  cat <<EOF >${TMPFILE}.yml
---
a:
  c:
    y:
      - 2
      - 10000
    x:
      - 1
      - 3
      - 101
  b:
    name: bep
    age: 19
EOF

  ${DIRNAME}/${BASENAME} --$Output ${TMPFILE}.yml
  exit 0
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
Output=json

# parse command line into arguments and check results of parsing
while getopts :dDhjsvy-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
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
    j|json)
      Output=json
      ;;
    s|selftest)
      Selftest=true
      ;;
    v|verbose)
      Verbose=true
      Verbose1="-v"
      ;;
    y|yaml)
      Output=yaml
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

if [[ $Selftest == true ]]
then
  Selftest
  exit 0
fi

if [[ $# -eq 0 ]]
then
  Usage >&2
  exit 1
fi

# Check for dependencies yq and jq
command -v yq >/dev/null 2>&1 || { echo "Error: yq is not installed." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is not installed." >&2; exit 1; }

read -r -d '' FILTER <<'EOF' || true
walk(
  if type == "array" then
    sort_by(if type == "object" and has("name") then [0, .name] else [1, .] end)
  elif type == "object" then
    to_entries | sort_by(.key) | from_entries
  else . end
)
EOF

for f in "$@"; do
  [[ -f "$f" ]] || { echo "Error: '$f' not found." >&2; exit 1; }
  if [[ $Output == json ]]
  then
    yq -j . $f | jq "$FILTER"
  else
    yq -j . $f | jq "$FILTER" | yq -y .
  fi 
done
