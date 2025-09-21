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

VAGRANT_BASE=${VAGRANT_BASE:-/data/vagrant}
VAGRANT_DEFAULT_PROVIDER=${VAGRANT_DEFAULT_PROVIDER:-virtualbox}
VAGRANT_HOME=${VAGRANT_BASE}/.vagrant.d
export VAGRANT_DEFAULT_PROVIDER VAGRANT_HOME

##############################################################
#
# Defining standarized functions
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

  -c|--command <cmd>   : SSH command to execute
  -f|--file <file>     : Use alternative configuration file

Examples:

Start SSH connection to box for project 'oracle' (single VM)
\$ $BASENAME_ROOT oracle ssh

Start SSH connection to box 'desktop-fedora41' for project 'desktop' (multi VM)
\$ $BASENAME_ROOT desktop ssh desktop-fedora41

EOF

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

# parse command line into arguments and check results of parsing
while getopts :c:dDf:hv-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    c|command)
      Command="$OPTARG"
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
    f|file)
      Vagrantfile=${OPTARG}
      [[ $Vagrantfile != /* ]] && Vagrantfile=${PWD}/${OPTARG}
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

if [[ $# -lt 2 ]]
then
  Usage >&2
  exit 1
fi

BOX=$1
MODE=$2
shift 2
ARGS="$@"

cd ${VAGRANT_BASE}
if [[ ! -d ${BOX} && ${MODE} == init ]]
then
  mkdir -p ${BOX}
fi

cd ${BOX}
#echo "Current path : $PWD"

case $MODE in
  init)
    if [[ -n ${Vagrantfile} ]]
    then
      cp ${Vagrantfile} Vagrantfile
    else
      [[ -f Vagrantfile ]] && echo "Already initialized!" >&2 && exit 1
      vagrant $MODE $BOX $ARGS
    fi
    ;;
  ssh)
    [[ ! -f Vagrantfile ]] && echo "Not initialized yet!" >&2 && exit 1
    if [[ -z $Command ]]
    then
      vagrant ssh $ARGS
    else
      vagrant ssh -c "$Command" $ARGS
    fi
    ;;    
  *)
    [[ ! -f Vagrantfile ]] && echo "Not initialized yet!" >&2 && exit 1
    vagrant $MODE $ARGS
    ;;
esac
