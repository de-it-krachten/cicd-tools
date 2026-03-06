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

CSVFILE=~/role-support.csv
ROLE=$(basename $PWD)


##############################################################
#
# Defining standardized functions
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

   -c|--commit          : Create commit for changed in support
   -o|--cicd-overwrite  : Update .cicd.overwrite file
   -s|--snapshot        : Create support snapshot file

EOF

}

function Get_headers
{

  # Convert TSV -> CSV
  sed -i "s/\t/;/g" $CSVFILE
  sed -i "s/^role;/name;/" $CSVFILE

  # Get headers
  Headers=$(awk 'NR==1' $CSVFILE | sed "s/;/ /g")
  xHeaders=$(awk 'NR==1' $CSVFILE | sed "s/;/ /g" | sed -r "s/([a-z0-9]+)/x\\1/g")

  # Get defaults
  IFS=";"
  eval read $Headers <<< "$(awk 'NR==2' $CSVFILE)"
  eval read $xHeaders <<< "$(awk -F';' '$1=="'$ROLE'" {print $0}' $CSVFILE)"
  unset IFS

}

function Cicd_overwrite
{

  # Create platfrom support overview
  for Header in $Headers
  do

    [[ $Header == name ]] && continue

    eval Value1=\$$Header
    eval Value2=\$x$Header

    [[ $Value1 == $Value2 ]] && continue

    [[ $first != false ]] && echo -e "\n# Supported platforms\nplatforms:"

    support=
    ci=

    case $Value2 in
      Y)
        support=true
        ci=true
        ;;
      y)
        support=true
        ci=false
        ;;
      N)
        support=false
        ci=false
        ;;
      x)
        echo "Warning: $Header is not defined!" >&2
        ;;
      *)
        echo "Unsupported value '$Value2' found" >&2
        exit 1
        ;;
    esac

    cat <<EOF
  $Header:
    supported: $support
    ci: $ci
EOF

    first=false
    counter=$(($counter+1))

  done > $TMPFILE

  # Append empty line
  [[ -s $TMPFILE ]] && echo >> $TMPFILE

  # Delete any platforms present
  sed -i '/# Supported platforms/,/^$/d' .cicd.overwrite
  sed -i '/platforms:/,/^$/d' .cicd.overwrite

  # Create supported platforms
  [[ -s $TMPFILE ]] && sed -i -e '/^generic:/,/^$/ { /^$/ { r '$TMPFILE'' -e 'd; }; }' .cicd.overwrite

  # Remove multiple empty lines 
  sed -i '/^$/N;/\n$/D' .cicd.overwrite

}

function Snapshot
{

  local Phase=$1

  [[ $Phase == pre ]] && File=.snapshot1
  [[ $Phase == post ]] && File=.snapshot2

  # Skip if snapshot file already exists
  [[ $Phase == pre && -s $File ]] && return 0

  yq -s '.[0] * .[1]' .cicd .cicd.overwrite | \
  yq -r '.platforms | to_entries | .[] | [.key, .value.name, .value.ci, .value.supported] | @csv' | \
  sed "s/,/|/g" | \
  sed "s/\"//g" > $File

}

function Commit
{

  # Move snapshot files
  mv .snapshot1 ${TMPFILE}snapshot1
  mv .snapshot2 ${TMPFILE}snapshot2

  # Commit all files
  git status
  git add .
  git commit -m "Update CI"

  for Distro in $Headers
  do

    # Translate some older distro identifiers
    Pre=$(awk -F'|' '$1 ~ "'$Distro'" {print $4}' ${TMPFILE}snapshot1)
    Post=$(awk -F'|' '$1 ~ "'$Distro'" {print $4}' ${TMPFILE}snapshot2)

    if [[ $Pre != $Post ]]
    then

      Os1=$(awk -F'|' '$1 ~ "'$Distro'" {print $2}' ${TMPFILE}snapshot1)
      Os2=$(awk -F'|' '$1 ~ "'$Distro'" {print $2}' ${TMPFILE}snapshot2)

#      if [[ $Os1 == "" ]]
#      then
#        echo "Unable to find existing distribution '$Distro" >&2
#        exit 1
#      fi

      if [[ $Os2 == "" ]]
      then
        echo "Unable to find distribution '$Distro" >&2
        exit 1
      fi

      if [[ $Post == true ]]
      then
        git commit -am "feat: Added support for $Os2" --allow-empty
      elif [[ $Pre == true && $Post == false ]]
      then
        git commit -am "feat: Drop support for $Os2" --allow-empty
      fi
    fi

  done

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
while getopts :cdDhos:v-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    c|commit)
      Mode=commits
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
    h|help)
      Usage
      exit 0
      ;;
    o|cicd-overwrite)
      Mode=cicd-overwrite
      ;;
    s|snapshot)
      Mode=snapshot
      Phase=$OPTARG
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
  # eval ${OPT}flag=1

done
shift $(($OPTIND -1))

if [[ ! -f $CSVFILE ]]
then
  echo "Role support matrix '$CSVFILE' could not be found!" >&2
  exit 0
fi

case $Mode in
  commits)
    Get_headers
    Commit
    ;;
  snapshot)
    Snapshot $Phase
    ;;
  cicd-overwrite)
    Get_headers
    Cicd_overwrite
    ;; 
esac
