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

WORKDIR=${TMPFILE}.workdir
[[ -f ${PWD}/${BASENAME_ROOT}.cfg ]] && Configfile=${PWD}/${BASENAME_ROOT}.cfg


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

  profiles=$(yq -y 'keys_unsorted' ${Configfile:-$CONFIGFILE} | sed "/---/d;s/- //" | tr '\n' ',' | sed "s/,$//")

  cat << EOF | grep -v "^#"

$BASENAME

Usage : $BASENAME <flags> <arguments>

Flags :

   -d|--debug           : Debug mode (set -x)
   -D|--dry-run         : Dry run mode
   -h|--help            : Prints this help message
   -v|--verbose         : Verbose output

   -b|--build           : Build new image (default)
   -B|--no-build        : Do not build new image
   -c|--configfile <f>  : Configfile to use
   -p|--push <registry> : Push image to specific registry (defaults to all registries)
   -P|--no-push         : Do not push image to any registry
   -x|--proxy <proxy>   : Proxy to use to connect to internal resources

Arguments:

   \$1  : image definition ($profiles)

EOF

}

function Prepare
{

  # Create working directory
  mkdir ${WORKDIR}

  export date=$(date +%Y%m%d)
  export template=$(yq -j '."'$profile'".template' $Configfile)

  yq -y '."'$profile'"' $Configfile > ${WORKDIR}/settings.yml
  echo "date: $date" >> ${WORKDIR}/settings.yml
  [[ -n $proxy ]] && proxy1="-x $proxy"

  jinjanate ${Template_dir}/${template} ${WORKDIR}/settings.yml > ${WORKDIR}/execution-environment.yml || exit 1
  [[ $Verbose == true ]] && cat ${WORKDIR}/execution-environment.yml

  # Download external files
  files=$(yq -j '."'$profile'".files' $Configfile)
  if [[ $files != null ]]
  then
    for row in $(echo $files | jq -r '.[] | @base64'); do
      _jq() {
       echo ${row} | base64 --decode | jq -r ${1}
      }
      src=$(echo $(_jq '.src'))
      dest=$(echo $(_jq '.dest'))
      curl --insecure $proxy1 -o ${WORKDIR}/$dest $src || exit 1
    done
  fi

}

function Build
{

  [[ $Build == false ]] && return 0

  jinjanate ${Template_dir}/${template} ${WORKDIR}/settings.yml > ${WORKDIR}/execution-environment.yml || exit 1

  cd ${WORKDIR}

  ansible-builder build -v3 --container-runtime=docker || exit 1

  cd - >/dev/null

  rm -fr ${WORKDIR}

}

function Push
{

  [[ $Push == false ]] && return 0

  set -e

  name=$(yq -jr '."'$profile'".name' $Configfile)
  registry1=$(yq -jr '."'$profile'".registry1' $Configfile)
  registry2=$(yq -jr '."'$profile'".registry2' $Configfile)

  if [[ $Registry == registry1 && ! $registry1 =~ ^(|null)$ ]]
  then
    [[ $registry1 =~ azurecr.io ]] && az acr login --name $registry1
    docker image push ${registry1}/${name}:${date}
    docker image push ${registry1}/${name}:latest
  fi

  if [[ $Registry == registry2 && ! $registry2 =~ ^(|null)$ ]]
  then 
    [[ $registry2 =~ azurecr.io ]] && az acr login --name $registry2
    docker image push ${registry2}/${name}:${date}
    docker image push ${registry2}/${name}:latest 
  fi 

  set +e

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

Build=true
Push=true

# parse command line into arguments and check results of parsing
while getopts bBc:dDhp:Pvx:-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    b|build)
      Build=true
      ;;
    B|no-build)
      Build=false
      ;;
    c|configfile)
      Configfile=$OPTARG
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
    p|push)
      Push=true
      Registry=$OPTARG
      ;;
    P|no-push)
      Push=false
      ;;
    v|verbose)
      Verbose=true
      Verbose1="-v"
      ;;
    x|proxy)
      proxy="$OPTARG"
      ;;
    *)
      echo "Unknown flag -$OPT given!" >&2
      exit 1
      ;;
  esac

  # Set flag to be use by Test_flag
  [[ ! $OPT =~ - ]] && eval ${OPT}flag=1

done
shift $(($OPTIND -1))

# Decide config file to use
Configfile=${Configfile:-$CONFIGFILE}

# Set template location to config directory
Template_dir=$(dirname $Configfile)/templates

if [[ $1 == "" ]]
then
  Usage >&2
  exit 1
fi

# Define profile name
profile=$1

# Get all profiles
profiles=$(yq -y 'keys_unsorted' $Configfile | sed "s/- //" | tr '\n' ',' | sed "s/,$//")

# Ensure the profile exists
if ! echo "$profiles" | sed "s/,/ /g" | grep -qw "$profile"
then
  echo "Profile '$profile' does not exist in '$Configfile'" >&2
  exit 1
fi

Prepare
Build
Push

# Now exit
exit 0
