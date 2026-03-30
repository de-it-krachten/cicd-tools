#!/bin/bash

PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH
BASENAME=$(basename $(readlink -f $0))
DIRNAME=$(dirname $(readlink -f $0))
BASENAME_ROOT=${BASENAME%%.*}
CONFIGFILE=${DIRNAME}/${BASENAME_ROOT}.yml
HOSTNAME=`hostname -f`
TMPFILE=$(mktemp)

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
    python3 -m venv $venv_tmp >/dev/null
    $venv_tmp/bin/pip3 install yq jinjanator jinjanator-plugin-ansible >/dev/null
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
    if ! jinjanate $Template > $File
    then
      exit 1
    fi
  fi

}


trap 'rm -f ${TMPFILE}*' EXIT

Verbose=false

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
Python=$(Get_key $Profile python)
Python=${Python:-$Python_default}
Python=${Python:-`readlink -f /usr/bin/python3`}

# Find the python & virtualenv to use
Get_executables

# Show settings
cat <<EOF
===============================================
virtualenv            : $Venv
python executable     : $Python
===============================================
EOF

sleep 2

if [[ $Virtenv == true ]]
then
  [[ $Delete == true ]] && rm -fr $Venv
  echo "Virtual environment : $Venv"
  Setup_venv $Venv $Python
fi

echo "$Pip_packages1" | sed "/^#/d" > ${TMPFILE}1
echo "$Pip_packages2" | sed "/^#/d" > ${TMPFILE}2

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
symlinks=$(yq -y '."'$Profile'".links' $Configfile | sed '/\.\.\./d;/null/d;/\[\]/d;s/^- //')
for symlink in $symlinks
do
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
