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
  
  Virtualenv=`command -v virtualenv-${Python_version}`
  Virtualenv=${Virtualenv:-`command -v virtualenv-3`}
  Virtualenv=${Virtualenv:-`command -v virtualenv`}

}

function Setup_venv
{

  local venv=$1
  local python=$2

  $sudo $python -m venv $venv || exit 1
  $sudo $venv/bin/pip3 install pip wheel setuptools setuptools_rust --upgrade || exit 1

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

yq=$(which yq 2>/dev/null)
e2j2=$(which e2j2 2>/dev/null)

if [[ $yq == "" || $e2j2 == "" ]]
then
  venv_tmp=/tmp/venv_tmp
  rm -fr $venv_tmp
  python3 -m venv $venv_tmp >/dev/null
  source $venv_tmp/bin/activate
  pip3 install yq e2j2 >/dev/null
fi

Configfile=${Configfile:-$CONFIGFILE}
if [[ -f ${Configfile}.j2 ]]
then
  if ! e2j2 -f ${Configfile}.j2
  then
    cat ${Configfile}.err >&2
    exit 1
  fi
fi

# Get list of packages
Pip_packages1=$(yq -y .generic.packages $Configfile | sed '/\.\.\./d;/null/d;/\[\]/d;s/^- //')
Pip_packages2=$(yq -y .$Profile.packages $Configfile | sed '/\.\.\./d;/null/d;/\[\]/d;s/^- //')

# Find the python & virtualenv to use
Get_executables

# Show settings
cat <<EOF
virtualenv            : $Venv
python executable     : $Python
virtualenv executable : $Virtualenv
Extra arguments       : $Virtenv_args
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
$Venv/bin/pip3 install -r ${TMPFILE}1 || exit 1
[[ -n $Pip_packages2 ]] && $Venv/bin/pip3 install -r ${TMPFILE}2
$Venv/bin/pip3 list

# Setup symlinks
Symlinks=$(yq -y .$Profile.links $Configfile | sed '/\.\.\./d;/null/d;/\[\]/d;s/^- //')
for link in $Symlinks
do
  ln -fs $Venv/bin/$link /usr/local/bin/$link
done
