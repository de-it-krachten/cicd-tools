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

TMP_PATH=/tmp/ansible-fqcn-converter


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

EOF

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
Echo=

# parse command line into arguments and check results of parsing
while getopts :dDhv-: OPT
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
      Verbose_level=2
      Verbose1="-v"
      Debug_level=$(( $Debug_level + 1 ))
      export Debug="set -vx"
      $Debug
      eval Debug${Debug_level}=\"set -vx\"
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

# When running in a virtual environment, make sure this python is discovered
if [[ -n $VIRTUAL_ENV ]]
then
  export PATH=${VIRTUAL_ENV}/bin:${PATH}
fi

# Retrieve github project 'ansible-fqcn-converter'
if [[ ! -d $TMP_PATH ]]
then
  git clone https://github.com/zerwes/ansible-fqcn-converter.git $TMP_PATH
fi

# Delete all external roles
${DIRNAME}/ansible-galaxy.sh -qC || exit 1

# Trying to find out
if [[ -d playbooks || -d roles ]]
then
  Ansible_type=playbooks
else
  Ansible_type=role
fi

# Migrate tasks & handlers
echo "Replacing tasks w/ FQCN named tasks"
if [[ $# -eq 0 ]]
then
  paths=`ls -d playbooks tasks handlers roles/*/tasks roles/*/handlers 2>/dev/null`
else
  paths="$@"
fi
 
for d in $paths
do
  echo "Replacing '$d'"
  if [[ -f $d ]]
  then
    f=$(basename $d)
    d=$(dirname $d)
    args="-d $d -f $f -x -w"
  else
    args="-d $d -x -w"
  fi
  $TMP_PATH/fqcn-fixer.py $args >${TMPFILE} 2>&1
  [[ $? -ne 0 ]] && cat ${TMPFILE} >&2 && exit 1
done

# Get all changes
echo "Get all renamed tasks"
for backupfile in `find . -name \*yml.bak 2>/dev/null`
do
  file=`echo $backupfile | sed "s/\.bak//"`
  diff -ruN $backupfile $file | grep "^+  [a-z]" | sed "s/^\+  //;s/:.*//"
  sed "/# possible ambiguous replacement:/d" $file > $TMPFILE
  cp $TMPFILE $file
  rm -f $backupfile
done | sort -u | cut -f1-2 -d. >> .collections.tmp

# Sort and remove duplicates
sort -o .collections.tmp -u .collections.tmp

# Make sure backup files do not get into the git repo
grep -s -q "\*.bak" .gitignore || echo "*.bak" >> .gitignore

echo "Collections required:"
cat .collections.tmp 

if [[ -s .collections.tmp ]]
then
  echo "collections:" > .collections
  cat .collections.tmp | sed "s/^/- /" >> .collections
else
  echo "collections: []" > .collections
fi

rm -f .collections.tmp

# List all modules and collections used
# This will add all collections to .collections
${DIRNAME}/ansible-list-modules.sh $Ansible_type || exit 1
