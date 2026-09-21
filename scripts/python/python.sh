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
CONFIGFILE=${DIRNAME}/${BASENAME_ROOT}.yml
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
HOSTNAME=$(hostname -f)


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

Sets up a Python environment

Usage : $BASENAME <flags>

Flags:

   -d        : Debug mode (set -x)
   -h        : Prints this help message
   -v        : Verbose output

   -c <file> : Configfile
   -e <exe>  : Python executable to use within virtualenv
   -g        : Set-up python environment globally
   -r        : Delete existing virtualenv before creating it
   -p <prof> : Profile
   -s        : Include site-packages in virtualenv
   -u        : Set-up python environment in user-space
   -V <path> : Set-up a virtuals python environment

Examples:

Set-up python environment globally :

\$ $BASENAME -g

Set-up python environment in user-space (not a virtualenv):
\$ $BASENAME -u

Set-up python environment in virtual envrionment '.venv' including site-packages
\$ $BASENAME -s -V <path>

EOF

}

function Get_executables
{

  Python=${Python:-`readlink -f /usr/bin/python3`}
  Python_version=`$Python --version | awk '{print $2}' | cut -f1,2 -d.`

}

function Setup
{

  yq=$(which yq 2>/dev/null)
  jinjanate=$(which jinjanate 2>/dev/null)

  if [[ $yq == "" || $jinjanate == "" ]]
  then
    venv_tmp=/tmp/venv_tmp
    rm -fr $venv_tmp
    echo "Setup temporary venv '$venv_tmp'"
    python3 -m venv $venv_tmp
    $venv_tmp/bin/pip3 install yq jinjanator jinjanator-plugin-ansible
    export PATH=$PATH:$venv_tmp/bin
  fi

}

function Setup_venv
{

  local venv=$1
  local python=$2

  $sudo $python -m venv $venv || exit 1
  $sudo $venv/bin/pip3 install pip wheel setuptools setuptools_rust --upgrade || exit 1

}

function Get_key
{

  local key=$1
  local subkey=$2

  if [[ -z $subkey ]]
  then
    yq -y '."'$key'"' $Configfile | sed '/\.\.\./d;/null/d;/\[\]/d;s/^- //'
  else
    yq -y '."'$key'".'$subkey'' $Configfile | sed '/\.\.\./d;/null/d;/\[\]/d;s/^- //'
  fi

}

function Template
{

  local Template File
  Template=$1
  File=${Template%%.j2}

  if [[ -f $Template ]]
  then
    if ! jinjanate $Template --quiet -o $File
    then
      exit 1
    fi
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

Virtenv=false
Global=false
Delete=false
Profile=default

# parse command line into arguments and check results of parsing
while getopts :c:de:ghp:rsSuvV: OPT
do
   case $OPT in
     c) Configfile=$OPTARG
        ;;
     d) set -vx
        ;;
     e) Python=$OPTARG
        ;;
     g) Mode=global
        Global=true
        ;;
     h) Usage
        exit 0
        ;;
     p) Profile=$OPTARG
        ;;
     s) Virtenv_args="--system-site-packages"
        ;;
     S) sudo=sudo
        ;;
     u) Mode=user
        Pip_args="--user"
        ;;
     r) Delete=true
        ;;
     v) Verbose=true
        ;;
     V) Mode=virtenv
        Virtenv=true
        Venv=$OPTARG
        ;;
     *) echo "Unknown flag -$OPT given!" >&2
        exit 1
        ;;
   esac

   # Set flag to be use by Test_flag
   eval ${OPT}flag=1

done
shift $(($OPTIND -1))

if [[ -z $Mode ]]
then
  Usage >&2
  exit 1
fi

Configfile=${Configfile:-$CONFIGFILE}

Setup

Template ${Configfile}.j2

# Get defaults
Python_default=$(Get_key default python)

# Check that profile exists
profile=$(Get_key $Profile)
[[ -z $profile ]] && echo "Profile '$Profile' does not exist" >&2 && exit 1

# Get list of packages
Pip_packages1=$(Get_key generic packages)
Pip_packages2=$(Get_key $Profile packages)
Python=${Python:-$(Get_key $Profile python)}
Python=${Python:-$Python_default}
Python=${Python:-$(readlink -f $(which python3))}

# Find the python & virtualenv to use
Get_executables

# Show settings
cat <<EOF
================================================================================
virtualenv            : $Venv
python executable     : $Python
================================================================================
EOF

sleep 2

if [[ $Virtenv == true ]]
then
  if [[ $Delete == true && -d $Venv ]]
  then
    echo "Deleting virtualenv as it already exists"
    rm -fr $Venv
  fi

  echo "Creating virtualenv"
  Setup_venv $Venv $Python

fi

echo "$Pip_packages1" | sed "/^#/d;/---/d" > ${TMPFILE}1
echo "$Pip_packages2" | sed "/^#/d;/---/d" > ${TMPFILE}2

# Install pypi packages
if [[ $Verbose == true ]]
then
  $Venv/bin/pip3 install -r ${TMPFILE}1 || exit 1
  [[ -n $Pip_packages2 ]] && $Venv/bin/pip3 install -r ${TMPFILE}2
else
  $Venv/bin/pip3 install -r ${TMPFILE}1 >/dev/null || exit 1
  [[ -n $Pip_packages2 ]] && $Venv/bin/pip3 install -r ${TMPFILE}2 >/dev/null
fi

# Setup symlinks
echo "Creating symlinks"
symlinks=$(yq -y '."'$Profile'".links' $Configfile | sed '/\.\.\./d;/---/d;/null/d;/\[\]/d;s/^- //')
for symlink in $symlinks
do
  echo "  > Creating symboc link '/usr/local/bin/$symlink' -> '$Venv/bin/$symlink'"
  ln -fs $Venv/bin/$symlink /usr/local/bin/$symlink
done

# Install requirements
reqs=$(yq -y .'"'$Profile'".requirements' $Configfile | sed '/\.\.\./d;/null/d;/\[\]/d;s/^- //')
for req in $reqs
do
  reqfile=$Venv/lib/$(basename $Python)/site-packages/ansible_collections/$req
  [[ -f $reqfile && $Verbose == true ]] && $Venv/bin/pip3 install -r $reqfile
  [[ -f $reqfile && $Verbose == false ]] && $Venv/bin/pip3 install -r $reqfile >/dev/null
done

# Show result
[[ $Verbose == true ]] && $Venv/bin/pip3 list

# Exit cleanly
exit 0
