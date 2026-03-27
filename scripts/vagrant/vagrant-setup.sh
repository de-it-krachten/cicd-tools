#!/bin/bash

# This script will convert a YAML based configuration file into
# a Vagrantfile

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

   -d|--debug         : Debug mode (set -x)
   -D|--dry-run       : Dry run mode
   -h|--help          : Prints this help message
   -v|--verbose       : Verbose output

   -a|--ansibledir <dir> : Main directory with Ansible code (default=$PWD)
   -c|--destroy          : Destroy VM and recreate them
   -C|--destroy-only     : Destroy VMs and do NOT recreate them
   -f|--file <file>      : YAML configuration to use (default: .vagrant.yml)
   -g|--update_galaxy    : Retrieve all Galaxy roles
   -i|--initial          : Perform bootstrap
   -r|--revert           : Revert snapshot
   -R|--revert-only      : Revert snapshot and exit
   -u|--update           : Update boxes
   -U|--update-prune     : Update boxes and prune old versions
   -x|--delete-all-boxes : Delete all boxes locally


EOF

}

function Get_var
{

  Default=""
  Json=true
  [[ $1 == --no-json ]] && Json=false && shift
  [[ $1 == --list ]] && Default="[]" && shift
  [[ $1 == --dict ]] && Default="{}" && shift

  Var=$1
  Key=$2

  if [[ $Json == true ]]
  then
    Value=$(yq -c .${Key} ${Vagrant_definition} | sed "s/\"/\\\\\"/g")
    [[ $Value == null ]] && Value="$Default"
    [[ -n $Value ]] && eval export \$Var=\"json:${Value}\"
  else
    Value=$(yq -r .${Key} ${Vagrant_definition})
    [[ $Value == null ]] && Value="$Default"
    [[ -n $Value ]] && eval export \$Var=${Value}
  fi 

}

function Vagrant_box_update
{

  # Get all outdated boxes
  vagrant box prune 
  vagrant box outdated --global --machine-readable | awk -F',' '$4=="warn" {print $5}' | awk '{print $2, $4}' | sed "s/'//g" | \
  while read Box Provider
  do
    vagrant box add $Box --provider=${Provider}
  done

}

function Vagrant_box_delete
{

  vagrant box list | \
  while read x y z
  do
    box=$x
    provider=$(echo $y | sed "s/(//;s/,//")
    version=$(echo $y | sed "s/)//")
    vagrant box remove $box --provider $provider
  done
  
}


##############################################################
#
# Main programs
#
#############################################################

# Make sure temporary files are cleaned at exit
trap 'rm -fr ${TMPDIR} ; [[ -z $Debug ]] && rm -f Vagrantfile.${Project}*' EXIT
trap 'exit 1' HUP QUIT KILL TERM INT

# Set the defaults
Verbose=false
Dry_run=false
Echo=

Destroy=false
Destroy_only=false
Initial=false
Update_galaxy=false
Vagrant_definition=.vagrant.yml
Ansibledir=$PWD
Update_boxes=false
Prune_boxes=false

# parse command line into arguments and check results of parsing
while getopts :a:cCdf:ghirRuUvx-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    a|ansibledir)
      Ansibledir=$OPTARG
      ;;
    c|destroy)
      Destroy=true
      Initial=true
      ;;
    C|destroy-only)
      Destroy=true
      Destroy_only=true
      Initial=true
      ;;
    d|debug)
      Debug=true
      set -vx
      ;;
    f|file)
      Vagrant_definition=$OPTARG
      ;;
    g|update_galaxy)
      Update_galaxy=true
      ;;
    h|help)
      Usage
      exit 0
      ;;
    i|initial)
      Initial=true
      ;;
    r|revert)
      Revert=true
      ;;
    R|revert-only)
      Revert=true
      Revert_only=true
      ;;
    u|update)
      Update_boxes=true
      Prune_boxes=false
      ;;
    U|update-prune)
      Update_boxes=true
      Prune_boxes=true
      ;;
    v|verbose)
      Verbose=true
      ;;
    x|delete-all-boxes)
      Vagrant_box_delete
      exit 0
      ;;
    *)
      echo "Unknown flag -$OPT given!" >&2
      exit 1
      ;;
  esac

  # Set flag to be use by Test_flag
  #eval ${OPT}flag=1

done
shift $(($OPTIND -1))

# Make sure the input file exists
if [[ ${Vagrant_definition} =~ \.j2$ ]]
then
  e2j2 -f ${Vagrant_definition} || exit 1
  Vagrant_definition=${Vagrant_definition%%.j2}
elif [[ -f ${Vagrant_definition}.j2 ]]
then
  e2j2 -f ${Vagrant_definition}.j2 || exit 1
elif [[ ! -f $Vagrant_definition ]]
then
  echo "File '$Vagrant_definition' not found!" >&2
  exit 1
fi

# Get project name from YAML .. if none found, use working directory
export Project=$(yq -j .vagrant_project $Vagrant_definition)
[[ $Project == null ]] && Project=$(basename $PWD)

# Get provider name
export Provider=$(yq -j .vagrant_provider $Vagrant_definition)
[[ $Provider == null ]] && Provider=${VAGRANT_DEFAULT_PROVIDER:-virtualbox}
export VAGRANT_DEFAULT_PROVIDER=${VAGRANT_DEFAULT_PROVIDER}

echo "Project  : $Project"
echo "Provider : $Provider"

Vagrantdir=${VAGRANT_BASE:-/data/vagrant}/${Project}
Inventorydir=${Vagrantdir}/.vagrant/provisioners/ansible/inventory
Ansibledir=$PWD
export Vagrantdir Ansibledir
echo "Path     : $Vagrantdir"

if [[ $Update_galaxy == true ]]
then
  [[ -d ansible ]] && cd ansible && a=true
  ansible-galaxy.sh -C
  ansible-galaxy.sh
  [[ $a == true ]] && cd ..
fi

Get_var vms vagrant_boxes.vms
Get_var ansible vagrant_boxes.ansible
#Get_var --no-json vm1 vagrant_boxes.vms[0].name
#Get_var --dict extra_vars vagrant_boxes.ansible.extra_vars
#Get_var --list groups vagrant_boxes.ansible.groups
#Get_var --list hosts vagrant_boxes.ansible.hosts 
Get_var playbooks vagrant_boxes.ansible.playbooks
#Get_var --dict ansible_options vagrant_boxes.ansible.options

# Create vagrant directory
export Vagrantdir Inventorydir
[[ ! -d ${Vagrantdir} ]] && mkdir ${Vagrantdir}
rm -fr ${Inventorydir}
[[ ! -d ${Inventorydir} ]] && mkdir -p ${Inventorydir}
[[ ! -d ${Inventorydir}/host_vars ]] && mkdir -p ${Inventorydir}/host_vars
[[ ! -d ${Inventorydir}/group_vars ]] && mkdir -p ${Inventorydir}/group_vars

## Write ansible variables files 
[[ $verbose == true ]] && echo "Writing host variables to '${Inventorydir}/host_vars/'"
hosts=$(yq -y .vagrant_boxes.ansible.host_vars $Vagrant_definition | yq -r 'keys[]' 2>/dev/null)
for host in $hosts
do
  yq -y '.vagrant_boxes.ansible.host_vars."'$host'"' $Vagrant_definition > ${Inventorydir}/host_vars/${host}.yml
done

[[ $verbose == true ]] && echo "Writing group variables to '${Inventorydir}/group_vars/"
groups=$(yq -y .vagrant_boxes.ansible.group_vars $Vagrant_definition | yq -r 'keys[]' 2>/dev/null)
for group in $groups
do
  yq -y '.vagrant_boxes.ansible.host_vars."'$group'"' $Vagrant_definition > ${Inventorydir}/group_vars/${group}.yml
done

[[ $verbose == true ]] && echo "Writing extra-vars to ${Vagrantdir}/"
yq -y .vagrant_boxes.ansible.extra_vars $Vagrant_definition > ${Vagrantdir}/ansible.extra_vars.yml
[[ $verbose == true ]] && echo "Writing group membership to ${Vagrantdir}/"
yq -y .vagrant_boxes.ansible.groups $Vagrant_definition > ${Vagrantdir}/ansible.groups.yml

# Create Vagrantfile from template
rm -f Vagrantfile.${Project} Vagrantfile.${Project}.j2
cp ${DIRNAME}/Vagrantfile.template.j2 Vagrantfile.${Project}.j2
if e2j2 -m "<=" -f Vagrantfile.${Project}.j2
then
  [[ $Verbose == true ]] && cat Vagrantfile.${Project} | grep -v "^$"
else
  cat Vagrantfile.${Project}.err 
  exit 1
fi
sed -i "/^$/d" Vagrantfile.${Project}
cp Vagrantfile.${Project} ${Vagrantdir}/Vagrantfile

# Update all boxes
#[[ $Update_boxes == true ]] && ${DIRNAME}/vagrant.sh "${Project}" box update
[[ $Update_boxes == true ]] && Vagrant_box_update
[[ $Prune_boxes == true ]] && ${DIRNAME}/vagrant.sh "${Project}" box prune --no-tty

# Find out if the vm's have already been created
${DIRNAME}/vagrant.sh "${Project}" status | grep "$vm1" | grep -q "not created" && Initial=true

[[ $Destroy == true ]] && ${DIRNAME}/vagrant.sh "${Project}" destroy --force
[[ $Destroy_only = true ]] && exit 0
[[ $Revert == true ]] && ${DIRNAME}/vagrant.sh "${Project}" snapshot restore snapshot1
[[ $Revert_only = true ]] && exit 0

# Setup all vms but w/out provisioners
${DIRNAME}/vagrant.sh "${Project}" up --no-provision

# Create inventory so we can add localhost
cat <<EOF > /tmp/inventory-local.ini
[local]
localhost ansible_connection=local
EOF

# Provision code
Phases=`yq -r .vagrant_boxes.ansible.playbooks[].phase $Vagrant_definition`
for Phase in $Phases
do

  # Only run the bootstrap at initial deployment
  [[ $Phase == bootstrap && $Initial != true ]] && continue

  # Run the ansible provisioner
  ${DIRNAME}/vagrant.sh "${Project}" provision --provision-with $Phase $vm1

  # Find out if a snapshot is required
  Snapshot=`yq -r .vagrant_boxes.ansible.playbooks $Vagrant_definition | jq '.[] | select(.phase=="'$Phase'") | .snapshot'`
  if [[ $Snapshot == true ]]
  then
    ${DIRNAME}/vagrant.sh "${Project}" snapshot list | grep -q snapshot1 || ${DIRNAME}/vagrant.sh "${Project}" snapshot save snapshot1
  fi

done
