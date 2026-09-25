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

CONFIGFILE=${DIRNAME}/ansible.yml
TEMPLATEFILE=${DIRNAME}/ansible.yml.j2

VENV_LIST_DEFAULT="
yq
e2j2
jinjanator
pproxy
docker-squash
ansible-navigator
ansiblecore216
ansiblecore218
ansiblecore219
ansiblecore220
ansiblecore221
awxkit
"

VENV_LIST=${VENV_LIST:-$VENV_LIST_DEFAULT}

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

function Print_separator
{ 
  printf "%80s\n" | tr ' ' '-'
}

function Jinjanator
{

  venv=${root_dir}/jinjanator
  python=$(which python3)

  # Show settings
  cat <<EOF 
================================================================================
virtualenv            : $venv
python executable     : $python
================================================================================
EOF

  $Sudo python3 -m venv $venv
  $Sudo $venv/bin/pip3 install pip wheel setuptools --upgrade
  $Sudo $venv/bin/pip3 install jinjanator jinjanator-plugin-ansible
  [[ $venv =~ $root_dir ]] && $Sudo ln -fs $venv/bin/jinjanate /usr/local/bin/jinjanate

}

function Yq
{

  venv=${root_dir}/yq
  python=$(which python3)

  # Show settings
  cat <<EOF 
================================================================================
virtualenv            : $venv
python executable     : $python
================================================================================
EOF

  $Sudo python3 -m venv $venv
  $Sudo $venv/bin/pip3 install pip wheel setuptools --upgrade
  $Sudo $venv/bin/pip3 install yq
  [[ $venv =~ $root_dir ]] && $Sudo ln -fs $venv/bin/yq /usr/local/bin/yq

}



function Template
{

  if [[ -f ${TEMPLATEFILE} ]]
  then
    $Sudo $venv/bin/jinjanate ${TEMPLATEFILE} --quiet -o ${CONFIGFILE}
  fi

}

function Venv
{

  [[ -n $Python_executable ]] && Args="-e $Python_executable"

#  Print_separator
#  echo "$venv"
  Print_separator
  echo "$Sudo ${DIRNAME}/python.sh $Args $Verbose1 -c ${DIRNAME}/ansible.yml -p $venv -V $root_dir/$venv"
  Print_separator
  $Sudo ${DIRNAME}/python.sh $Args $Verbose1 -c ${DIRNAME}/ansible.yml -p $venv -V $root_dir/$venv
  $Sudo rm -fr $root_dir/$venv/lib/python3.*/site-packages/selinux

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
while getopts :dhp:sv-: OPT
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
      set -vx
      ;;
    h|help)
      Usage
      exit 0
      ;;
    p|python)
      Python_executable=$OPTARG
      ;;
    s|sudo)
      Sudo=sudo
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

done
shift $(($OPTIND -1))

root_dir=$1

if [[ -z $root_dir ]]
then
  echo "Usage   : $0 <venv-root-dir>" >&2
  echo "Example : $0 /usr/local/venv" >&2
  exit 1
fi

# Setup yq & jinjanator
Yq
Jinjanator

# Create from template
Template

# Setup generic
for venv in $VENV_LIST
do
  Venv
done
