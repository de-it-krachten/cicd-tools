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

DOCKER_HOST=${DOCKER_HOST:-127.0.0.1}
DOCKER_PORT=${DOCKER_PORT:-2375}

DOCKER_PROTECT="zabbix-agent2"


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

Usage : $BASENAME <flags>

Flags :

   -d          : Debug mode (set -x)
   -D          : Dry run mode
   -h          : Prints this help message
   -v          : Verbose output

   -c          : Clean all docker containers
   -i          : Clean all docker images
   -V          : Clean all volumes
   -p          : Execute system & network prune
   -s          : Execute commands as 'root' (depends on 'sudo')

   -f <filter> : Only remove containers that have this string in the name
                 It will find containers that meet the requirements of this regex filter.
   -r          : Delete containers/images from remote host ($DOCKER_HOST)
   -R <host>   : Delete containers/images from remote host specified

   --podman    : Uses podman instead of docker


Examples:

Clean all containers locally
\$ $BASENAME

Delete all containers & images remotely
\$ $BASENAME -r -c

Delete all containers remotely that have string 'abc123' in their name
\$ $BASENAME -r -f 'abc123'

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
#Verbose=false
Verbose=true
Verbose_level=0
Dry_run=false
Echo=

Delete_containers=false
Delete_external_containers=false
Delete_images=false
Delete_volumes=false
System_prune=false
Remote=false
Filter=""
Docker=docker
Tries=3
Sudo=

# parse command line into arguments and check results of parsing
while getopts :cdDf:hirpR:svVx-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    c) Delete_containers=true
       ;;
    d) set -vx
       ;;
    D) Dry_run=true
       Echo=echo
       ;;
    f) Filter="$OPTARG"
       ;;
    h) Usage >&2
       exit 0
       ;;
    i) Delete_images=true
       ;;
    p) System_prune=true
       ;;
    r) Remote=true
       Docker="docker --host tcp://${DOCKER_HOST}:${DOCKER_PORT}"
       ;;
    R) Remote=true
       Docker="docker --host tcp://${OPTARG}"
       ;;
    s) [[ $(id -un) != root ]] && Sudo=sudo
       ;;
    v) Verbose=true
       ;;
    V) Delete_volumes=true
       ;;
    x) Delete_external_containers=true
       ;;
    podman)
       Docker="podman"
       ;;
    docker)
       Docker="docker"
       ;;
    *) echo "Unknown flag -$OPT given!" >&2
       exit 1
       ;;
  esac

  # Set flag to be use by Test_flag
  eval ${OPT}flag=1

done
shift $(($OPTIND -1))


# Containers
if [[ $Delete_containers == true ]]
then
  echo "Show all running containers"
  $Sudo $Docker container ls -a

  echo "Stop all running containers"
  Containers=$($Sudo $Docker container ls -a | awk 'NR>1' | grep -E "$Filter" | grep -E -v "$DOCKER_PROTECT" | awk '{print $1}')
  echo "$Containers" | xargs -r $Echo $Sudo $Docker container kill

  echo "Delete all containers"
  echo "$Containers" | xargs -r $Echo $Sudo $Docker container rm
else
  echo "Skipping containers"
fi

# External Containers
if [[ $Delete_external_containers == true ]]
then

  echo "Show all running containers"
  $Sudo $Docker container ls -a --external

  echo "Stop all running containers"
  Containers=$($Sudo $Docker container ls -a --external | awk 'NR>1' | grep -E "$Filter" | grep -E -v "$DOCKER_PROTECT" | awk '{print $1}')
  echo "$Containers" | xargs -r $Echo $Sudo $Docker container kill

  echo "Delete all containers"
  [[ $Docker == docker ]] && echo "$Containers" | xargs -r $Echo $Sudo $Docker container rm
  [[ $Docker == podman ]] && echo "$Containers" | xargs -r $Echo $Sudo $Docker container rm --force
else
  echo "Skipping containers"
fi

# Images
if [[ $Delete_images == true ]]
then
  Try=1
  while [[ $Try -le $Tries ]]
  do
    echo "Delete all dockers images (attempt $Try)"
    [[ $Docker == docker ]] && Images=$($Sudo $Docker image ls -a --format json | jq -r .ID)
    [[ $Docker == podman ]] && Images=$($Sudo $Docker image ls -a --format json | jq -r '.[].Id')
    [[ $Docker == docker ]] && echo "$Images" | xargs -r $Echo $Sudo $Docker image rm
    [[ $Docker == podman ]] && echo "$Images" | xargs -r $Echo $Sudo $Docker image rm --force
    Try=$(($Try+1))
  done
else
  echo "Skipping images"
fi

# Volumes
if [[ $Delete_volumes == true ]]
then
  Try=1
  while [[ $Try -le $Tries ]]
  do
    echo "Delete all dockers volumes (attempt $Try)"
    [[ $Docker == docker ]] && Volumes=$($Sudo $Docker volume ls --format json | jq -r .ID)
    [[ $Docker == podman ]] && Volumes=$($Sudo $Docker volume ls --format json | jq -r '.[].Id')
    [[ $Docker == docker ]] && echo "$Volumes" | xargs -r $Echo $Sudo $Docker volume rm
    [[ $Docker == podman ]] && echo "$Volumes" | xargs -r $Echo $Sudo $Docker volume rm
    Try=$(($Try+1))
  done
else
  echo "Skipping volumes"
fi

# System / network prune
if [[ $System_prune == true ]]
then
  echo "Performing system prune"
  $Echo $Sudo $Docker system prune -a -f

  echo "Performing network prune"
  $Echo $Sudo $Docker network prune -f

else
  echo "Skipping system/network prune"
fi

if [[ $Verbose == true ]]
then
  echo "Current situtation:"
  echo "=== Containers"
  [[ $Docker == docker ]] && $Sudo $Docker container ls -a --format table
  [[ $Docker == podman ]] && $Sudo $Docker container ls -a
  echo
  echo "=== Images"
  [[ $Docker == docker ]] && $Sudo $Docker image ls -a --format table
  [[ $Docker == podman ]] && $Sudo $Docker image ls -a
  echo
  echo "=== Volumes"
  [[ $Docker == docker ]] && $Sudo $Docker volume ls --format table
  [[ $Docker == podman ]] && $Sudo $Docker volume ls
  echo
  echo "=== Networks"
  [[ $Docker == docker ]] && $Sudo $Docker network ls --format table
  [[ $Docker == podman ]] && $Sudo $Docker network ls
fi

# Now exit
exit 0
