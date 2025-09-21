#!/bin/bash

# Get the name of the calling script
FILENAME=$(readlink -f $0)
BASENAME="${FILENAME##*/}"
BASENAME_ROOT=${BASENAME%%.*}
DIRNAME="${FILENAME%/*}"

TEMPLATE=docker


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

function Create_from_template
{

  local File=$1
  local Template=${1}.j2

  cp ${DIRNAME}/${TEMPLATE}/templates/${Template} /tmp
  e2j2 -f /tmp/${Template}
  cp /tmp/${Template} ${File}

}


Dry_run=false
Github_self_hosted=false
Initialize=false

# parse command line into arguments and check results of parsing
while getopts :dDhv OPT
do
   case $OPT in
     d) Verbose=true
        Verbose1="-v"
        export Debug="set -vx"
        $Debug
        ;;
     D) Dry_run=true
        Dry_run1="-D"
        Echo=echo
        ;;
     h) Usage
        exit 0
        ;;
     v) Verbose=true
        Verbose_level=$(($Verbose_level+1))
        Verbose1="-v"
        ;;
     *) echo "Unknown flag -$OPT given!" >&2
        exit 1
        ;;
   esac

   # Set flag to be use by Test_flag
   eval ${OPT}flag=1

done
shift $(($OPTIND -1))

Template=docker

# Test for all needed executables
Executable_test docker
Executable_test ansible
Executable_test ansible-playbook

#Create_from_template docker.properties
#Create_from_template 
