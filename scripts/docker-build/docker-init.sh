#!/bin/bash -e
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
BASENAME_ROOT=${BASENAME%%.*}
DIRNAME="${FILENAME%/*}"

# Define temorary files, debug direcotory, config and lock file
TMPDIR=$(mktemp -d)
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

[[ $DIRNAME == /usr/local/bin ]] && TEMPLATEDIR=/usr/local/${BASENAME_ROOT} || TEMPLATEDIR=${DIRNAME}


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

   -d|--debug   : Debug mode (set -x)
   -D|--dry-run : Dry run mode
   -h|--help    : Prints this help message
   -v|--verbose : Verbose output

   -c|--color   : Execute w/ color (default)
   -C|--no-color: Execute w/out color
   -g|--gitlab  : Activate Gitlab CI

EOF

}

function File
{

  File=$1

  if [[ ! -f $File ]]
  then
    cp ${DIRNAME}/templates/${File} ${PWD}
  fi

}


function Template
{

  File=$1

  if [[ -f $File ]]
  then
    echo "File '$File' already present!" >&2
  else
    [[ $Colors == false ]] && Args="--no-color"
    cp ${DIRNAME}/templates/${File}.j2 ${PWD}
    e2j2 $Args -m "<=" -f ${File}.j2 || exit 1
    rm -f ${File}.j2
  fi

}

##############################################################
#
# Main programs
#
#############################################################

# Make sure temporary files are cleaned at exit
trap 'rm -fr ${TMPDIR}*' EXIT
trap 'exit 1' HUP QUIT KILL TERM INT

# Set the defaults
Debug_level=0
Verbose=false
Verbose_level=0
Dry_run=false
Echo=
Colors=true

# parse command line into arguments and check results of parsing
while getopts :cCdDghv-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    c|color)
      Colors=true
      ;;
    C|no-color)
      Colors=false
      ;;
    d|debug)
      set -vx
      Verbose=true
      Verbose1="-v"
      ;;
    D|dry-run)
      Dry_run=true
      Dry_run1="-D"
      Echo=echo
      ;;
    g|gitlab)
      Ci=gitlab
      ;;
    h|help)
      Usage
      exit 0
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

# Create files from template
Template docker-settings.yml
Template Dockerfile.j2
Template build-custom.yml
Template requirements.yml
[[ $Ci == gitlab ]] && Template .gitlab-ci.yml

# Exit w/out errors
exit 0
