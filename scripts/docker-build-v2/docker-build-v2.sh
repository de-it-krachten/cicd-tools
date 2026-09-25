#!/bin/bash -e

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

   -d|--debug             : Debug mode (set -x)
   -D|--dry-run           : Dry run mode
   -h|--help              : Prints this help message
   -v|--verbose           : Verbose output

   -b|--build             : Perform build phase (default)
   -B|--no-build          : Do not perform build phase
   -c|--configfile <file> : Configuration file to use (required) 
   -F|--force             : Force initialization
   -i|--init              : Execute initialization
   -p|--push              : Push image to registry
   -P|--no-push           : Do not push image to registry (default)

Examples:

Initialize a new project
\$ $BASENAME --init

Create new image, but do not push it
\$ $BASENAME --build

Push an already made image
\$ $BASENAME --no-build --push

EOF

}

function Init
{

  Template     ${DIRNAME}/templates/docker-settings.yml.j2.j2 docker-settings.yml.j2
  Template -cp ${DIRNAME}/templates/Dockerfile.j2.j2          Dockerfile.j2
  Template -cp ${DIRNAME}/templates/playbook.yml.j2           playbook.yml
  Template     ${DIRNAME}/templates/requirements.yml.j2       requirements.yml

}

function Template
{

  Mode=template
  [[ $1 == -cp ]] && Mode=copy && shift

  local Template=$1
  local File=$2

  if [[ -f $File ]]
  then
    if [[ $Force == false ]]
    then
      echo "File '$File' already exists!" >&2
      return 0
    else
      mv $File ${File}.${TIMESTAMP}
    fi
  fi
 
  if [[ $Mode == copy ]]
  then
    cp $Template $File
  else
    jinjanator.sh -o $File $Template
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

Build=true
Push=false
Init=false
Force=false

# parse command line into arguments and check results of parsing
while getopts :bBc:dDFhipPv-: OPT
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
    F|force)
      Force=true 
      ;;
    h|help)
      Usage
      exit 0
      ;;
    i|init)
      Init=true
      ;;
    p|push)
      Push=true
      ;; 
    P|no-push)
      Push=false
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

if [[ $Init == true ]]
then
  Init
  exit 0
fi

if [[ -z $Configfile ]]
then
  echo "No configuration file defined!" >&2
  exit 1
fi

if [[ ! -f $Configfile ]]
then
  echo "File '$Configfile' not found!" >&2
  exit 1
fi

# Generate configuration file from template
if [[ $Configfile =~ \.j2$ ]]
then
  export DATESTAMP
  Template=$Configfile
  Configfile=$(echo $Configfile | sed "s/\.j2//")
  yq -y . $Template > $TMPFILE
  jinjanator.sh $TMPFILE > $Configfile
fi

# Generate custom base image from Dockerfile
Custom_build=$(yq -jr .custom_image.build $Configfile)
if [[ $Custom_build == true ]]
then
  Name=$(yq -jr .custom_image.name $Configfile)
  Parent=$(yq -jr .custom_image.parent $Configfile)
  Dockerfile=$(yq -jr .custom_image.dockerfile $Configfile)
  export Parent

  if [[ $Dockerfile =~ \.j2$ ]]
  then
    jinjanator.sh $Dockerfile > Dockerfile
  fi

  docker pull $Parent
  docker build -t $Name .

fi

# Build image
echo "============================================================"
echo "Build phase"
echo "============================================================"
if [[ $Build == true ]]
then

  echo "=== Copy ansible code"
  # Setup ansible directory
  Playbook=$(yq -jr .ansible.playbook $Configfile)
  export ansible_dir=/tmp/ansible.$$
  mkdir $ansible_dir
  mkdir $ansible_dir/roles
  cp $Playbook $ansible_dir/
  cp requirements.yml $ansible_dir/roles
  [[ -d additional_files ]] && cp -r additional_files/* $ansible_dir/
  echo "=== Get ansible roles"
  ansible-galaxy install -r $ansible_dir/roles/requirements.yml -p $ansible_dir/roles
  echo "=== Get ansible collections"
  ansible-galaxy collection install -r $ansible_dir/roles/requirements.yml

  Parent_settings=$(yq -jr .image.inherit_parent_settings $Configfile)
  if [[ $Parent_settings == true ]]
  then
    cp $Configfile ${TMPFILE}.yml
    Configfile=${TMPFILE}.yml
    Parent_image=$(yq -jr .image.parent $Configfile)
    echo "=== Pull docker parent image"
    docker pull $Parent_image
    echo "=== Get parent config"
    docker image inspect --format '{{json .Config}}' $Parent_image | jq '{
      parent_settings: [
        (.User       | select(. // "" != "") | "USER \(.)"),
        (.WorkingDir | select(. // "" != "") | "WORKDIR \(.)"),
        (.Env[]?     | "ENV \(.)"),
        (.Entrypoint | select(. != null) | "ENTRYPOINT \(tojson)"),
        (.Cmd        | select(. != null) | "CMD \(tojson)"),
        (.StopSignal | select(. // "" != "") | "STOPSIGNAL \(.)"),
        (.ExposedPorts // {} | keys[]? | "EXPOSE \(.)"),
        (.Volumes      // {} | keys[]? | "VOLUME \(.)"),
        (.Labels // {} | to_entries[]? | "LABEL \(.key)=\(.value)")
      ]
    }' | yq -y . >> $Configfile
  fi

  if [[ $Verbose == true ]]
  then
    echo "=== Show docker-build configuration"
    cat $Configfile
  fi

  echo "=== Create packer configuration in YAML"
  jinjanator.sh -s "<=" ${DIRNAME}/build.yml.j2 $Configfile > build.yml

  echo "=== Convert to packer HCL-json"
  yq -j . build.yml > build.pkr.json
  [[ $Verbose == true ]] && cat build.yml
  [[ $Debug == true ]] && Args="-debug"
  echo "=== Create docker image using packer"
  packer build $Args build.pkr.json
  rm -f build.pkr.json build.yml
else
  echo "Skipping ..."
fi

# Push image
echo "============================================================"
echo "Push phase"
echo "============================================================"
if [[ $Push == true ]]
then
  image_name=$(yq -jr .image.name $Configfile)
  images=$(docker image ls | grep "$image_name" | awk '{print $1}')
  for image in $images
  do
    docker push $image
  done
else
  echo "Skipping ..."
fi
