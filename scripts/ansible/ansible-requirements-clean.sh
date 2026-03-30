#!/bin/bash
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
TMPDIR=/tmp
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
for Functions in ${FUNCTIONS}
do
  if [[ -f ${Functions} ]]
  then
     . ${Functions}
  fi
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

   -d|--debug   : Debug mode (set -x)
   -D|--dry-run : Dry run mode
   -h|--help    : Prints this help message
   -v|--verbose : Verbose output

EOF

}

function Clean_role
{

  if [[ -e ${Path}roles/$Role ]]
  then
    if [[ -L ${Path}roles/$Role ]]
    then
      [[ $Verbose_level -gt 0 ]] && echo "Leaving symbolic link '${Path}roles/$Role'" >&2
      return 0
    elif [[ -d ${Path}roles/$Role/.git ]]
    then
      if [[ $Force == true ]]
      then
        $Echo rm -fr ${Path}roles/$Role
      else
        [[ $Verbose_level -gt 0 ]] && echo "Leaving repository '${Path}roles/$Role' due to presence of .git directory" >&2
      fi
    elif [[ -d ${Path}roles/$Role ]]
    then
      [[ $Verbose_level -gt 0 ]] && echo "Removing '${Path}role/$Role'" >&2
      $Echo rm -fr ${Path}roles/$Role
    fi
  else
    [[ $Verbose_level -gt 0 ]] && echo "Role '${Path}${Role}' not found"
  fi

  # Update .gitignore to exclude external roles
  [[ $Dry_run == false && $Gitignore == true ]] && Gitignore

  # Update .ansible-lint to exclude external roles
  [[ $Dry_run == false && $Ansible_lint == true ]] && Ansible_lint

}


##############################################################
#
# Main programs
#
#############################################################

# Make sure temporary files are cleaned at exit
trap 'rm -f ${TMPFILE}*' EXIT
trap 'exit 1' HUP QUIT KILL TERM INT

# Set the defaults
Debug_level=0
Verbose=false
Verbose_level=0
Dry_run=false
Force=false
Echo=
Gitignore=false
Ansible_lint=false

# parse command line into arguments and check results of parsing
while getopts :aAdDFgGhp:qv-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    a)
      Ansible_lint=true
      ;;
    A)
      Ansible_lint=false
      ;;
    d|debug)
      Verbose=true
      Verbose_level=2
      set -vx
      ;;
    D|dry-run)
      Dry_run=true
      Dry_run1="-D"
      Echo=echo
      ;;
    F)
      Force=true
      ;;
    g)
      Gitignore=true
      ;;
    G)
      Gitignore=false
      ;;
    h|help)
      Usage
      exit 0
      ;;
    p|path)
      Path=$OPTARG
      ;;
    q|quiet)
      Verbose_level=-1
      ;;
    v|verbose)
      Verbose=true
      Verbose_level=$(($Verbose_level+1))
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

# Use custom path
[[ -n $Path ]] && Path="${Path}/"

# parameters
Reqfile=${1:-roles/requirements.yml}

Galaxy=`which ansible-galaxy 2>/dev/null`
if [[ ! -x $Galaxy ]]
then
  echo "ansible-galaxy executable not found!" >&2
  exit 1
fi

# Get all external roles including dependencies
Roles=$(Yamlloop)

# Loop over each role
for Role in $Roles
do
  Clean_role
done

# Delete other roles
Roles=$(ls -d ${Path}roles/deitkrachten.* 2>/dev/null | sed "s/roles\///")
for Role in $Roles
do
  Clean_role
done

# Update .gitignore to exclude external roles
#[[ $Dry_run == false && $Gitignore == true ]] && Gitignore

# Update .ansible-lint to exclude external roles
#[[ $Dry_run == false && $Ansible_lint == true ]] && Ansible_lint
