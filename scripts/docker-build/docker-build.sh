#!/bin/bash -e
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
TMPDIR=$(mktemp -d)
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

[[ $DIRNAME == /usr/local/bin ]] && TEMPLATEDIR=/usr/local/${BASENAME_ROOT} || TEMPLATEDIR=${DIRNAME}

DOCKER_CONFIG=$HOME/.docker/config.json


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

   -d|--debug           : Debug mode (set -x)
   -D|--dry-run         : Dry run mode
   -h|--help            : Prints this help message
   -v|--verbose         : Verbose output

   -b|--build           : Run build phase (default)
   -B|--no-build        : Do not run build phase
   -c|--color           : Execute w/ color (default)
   -C|--no-color        : Execute w/out color
   -k|--no-cleanup-pre  : Do not cleanup image/container prior to the build process
   -K|--no-cleanup-post : Do not cleanup image/container after the build process
   -p|--push            : Push docker image to registry
   -P|--no-push         : Do not push docker image to registry (default)
   -t|--tool <tool>     : Tool to use (podman or docker. Default = docker)
   -X|--clcred          : Clear docker credentials

EOF

}

function Cleanup
{

  echo "Cleanup temporary files"
  [[ $Debug == false ]] && rm -fr ${TMPDIR}
  [[ $Docker_config_clean == true ]] && rm -f ${DOCKER_CONFIG}
  /bin/true

}

function OS_settings
{

  # Import OS specifics
  if [[ -f /etc/os-release ]]
  then
    source /etc/os-release
  fi

}

function Setup
{

  # Force Ansible to use colors
  export PY_COLORS=1
  export ANSIBLE_FORCE_COLOR=1

  echo "Copying ansible code into temporary directory '${TMPDIR}'"
  rsync -av ${TEMPLATEDIR}/ansible ${TMPDIR}
  cp docker-settings.yml ${TMPDIR}/ansible
  [[ -f requirements.yml ]] && cp requirements.yml ${TMPDIR}/ansible/roles
  [[ -f build-custom.yml ]] && cp build-custom.yml ${TMPDIR}/ansible
  [[ -d additional_files ]] && rsync -av additional_files/ ${TMPDIR}/ansible

  cd ${TMPDIR}/ansible
  Ansible_args="-i localhost, -c local $Verbose1"
  ansible-galaxy install -r ${TMPDIR}/ansible/roles/requirements.yml -p ${TMPDIR}/ansible/roles/ --ignore-errors

}


##############################################################
#
# Main programs
#
#############################################################

# Make sure temporary files are cleaned at exit
trap 'cd / ; Cleanup' EXIT
trap 'exit 1' HUP QUIT KILL TERM INT

# Set the defaults
Debug=false
Debug_level=0
Verbose=false
Verbose_level=0
Dry_run=false
Echo=

Build=true
Build_refresh=true
Push=false
Cleanup_pre=true
Cleanup_post=true
Docker_config_clean=false
Colors=true
Container_tool=docker

# parse command line into arguments and check results of parsing
while getopts :bBcCdDghkKpPt:vX-: OPT
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
      Build_refresh=false
      ;;
    c|color)
      Colors=true
      ;; 
    C|no-color)
      Colors=false
      ;;
    d|debug)
      Debug=true
      Verbose=true
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
    k|no-cleanup-pre)
      Cleanup_pre=false
      ;;
    K|no-cleanup-post)
      Cleanup_post=false
      ;;
    p|push)
      Push=true
      ;;
    P|no-push)
      Push=false
      ;;
    t|tool)
      Container_tool=$OPTARG
      ;;
    v|verbose)
      Verbose=true
      Verbose_level=$(($Verbose_level+1))
      Verbose1+=" -v"
      ;;
    X|clcred)
      Docker_config_clean=true
      ;;
    docker)
      Container_tool=docker
      ;;
    podman)
      Container_tool=podman
      ;;
    *)
      echo "Unknown flag -$OPT given!" >&2
      exit 1
      ;;
  esac

#  # Set flag to be use by Test_flag
#  eval ${OPT}flag=1

done
shift $(($OPTIND -1))


#----------------------------------------------------------
# export variables
#----------------------------------------------------------

# Enable/disable colors
if [[ $Colors == true ]]
then
  export PY_COLORS=1
  export ANSIBLE_FORCE_COLOR=1
  export ANSIBLE_NOCOLOR=0
else
  export PY_COLORS=0
  export ANSIBLE_FORCE_COLOR=0
  export ANSIBLE_NOCOLOR=1
fi

export SOURCE_PATH=$PWD
export DOCKER_BINARY=$Container_tool
export DOCKER_CLEANUP_PRE=$Cleanup_pre
export DOCKER_BUILD=$Build
export DOCKER_BUILD_REFRESH=$Build_refresh
export DOCKER_PUSH=$Push
export DOCKER_CLEANUP_POST=$Cleanup_post

cat <<EOF
=================================================================
variables
=================================================================
TMPDIR=$TMPDIR
DOCKER_BINARY=$Container_tool
DOCKER_CLEANUP_PRE=$Cleanup_pre
DOCKER_BUILD=$Build
DOCKER_BUILD_REFRESH=$Build_refresh
DOCKER_PUSH=$Push
DOCKER_CLEANUP_POST=$Cleanup_post
EOF

OS_settings

if [[ ! -f docker-settings.yml ]]
then
  echo "Docker build project not initialized!" >&2
  echo "Execute 'docker-init.sh' and edit docker-settings.yml to reflect your requirements." >&2
  exit 1
fi


#----------------------------------------------------------
# set-up required structure
#----------------------------------------------------------

echo "================================================================="
echo "Executing setup phase"
echo "================================================================="
Setup


#----------------------------------------------------------
# cleanup previously created image / container
#----------------------------------------------------------

if [[ $Cleanup_pre == true ]]
then
  echo "================================================================="
  echo "Executing cleanup phase (pre)"
  echo "================================================================="

  ansible-playbook ${TMPDIR}/ansible/build-cleanup.yml $Ansible_args

fi

#----------------------------------------------------------
# build image
#----------------------------------------------------------

#if [[ $Build == true ]]
#then
  echo "================================================================="
  echo "Executing build phase"
  echo "================================================================="

  ansible-playbook ${TMPDIR}/ansible/build.yml $Ansible_args

#fi


#----------------------------------------------------------
# push image
#----------------------------------------------------------

if [[ $Push == true ]]
then
  echo "================================================================="
  echo "Executing push phase"
  echo "================================================================="

  if [[ -n $DOCKER_AUTH_CONFIG && ! -f ${DOCKER_CONFIG} ]]
  then
    echo "Writing docker credentials"
    echo "${DOCKER_AUTH_CONFIG}" | jq . > ${DOCKER_CONFIG}
    Docker_config_clean=true
  fi

  ansible-playbook ${TMPDIR}/ansible/push.yml $Ansible_args
fi


#----------------------------------------------------------
# cleanup image / container
#----------------------------------------------------------

if [[ $Cleanup_post == true ]]
then
  echo "================================================================="
  echo "Executing cleanup phase (post)"
  echo "================================================================="

  ansible-playbook ${TMPDIR}/ansible/build-cleanup.yml $Ansible_args

fi

# Exit cleanly
exit 0
