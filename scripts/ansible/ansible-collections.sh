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
TMPDIR=$(mktemp -d)
TMPFILE=${TMPDIR}/${BASENAME}.${RANDOM}.${RANDOM}

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
for functions in $FUNCTIONS
do
  [[ -f ${functions} ]] && . ${functions}
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

   -d|--debug          : Debug mode (set -x)
   -D|--dry-run        : Dry run mode
   -h|--help           : Prints this help message
   -v|--verbose        : Verbose output

   -c|--coldir <path>  : Custom collection location to use
   -f|--format [v1|v2] : Output format (default=v2)
   -r|--roledir <path> : Directory to search for roles (default=roles)

EOF

}

function Template
{

  local Template=$1
  local File=${Template%%.j2}

  # Check for supported jinja2 template tools
  if [[ -x /usr/local/bin/jinjanate ]]
  then
    if ! jinjanate --quiet $Template > $File
    then
      exit 1
    fi
  else
    echo "Jinjanate is required!" >&2
    exit 1
  fi

#  # Show result
#  [[ $Verbose == true ]] && cat $File

}

function Collections_default
{

  [[ $Verbose == true ]] && echo "Create list of default collection dependencies"

  # Create minimal required collections
  cat <<EOF > ${TMPFILE}base
---
collections:
- name: ansible.posix
- name: ansible.windows
- name: community.docker
- name: community.general
- name: community.windows
EOF

 [[ $Verbose == true ]] && cat ${TMPFILE}base

}

function Collections_custom
{

  [[ $Verbose == true ]] && echo "Create list of custom collection dependencies"

  # Render all templates
  Collection_templates=$(ls .collections.j2 ${Roledir}/*/.collections.j2 2>/dev/null)
  for Collection_template in $Collection_templates
  do
    Template $Collection_template
  done

  # Get all collection files
  Collection_files=$(ls .collections ${Roledir}/*/.collections 2>/dev/null)

  # Merge all
  yq -y -S . $Collection_files > ${TMPFILE}custom
  [[ $Verbose == true ]] && cat ${TMPFILE}custom

}

function Collections_merge
{

  [[ $Verbose == true ]] && echo "Merge default and custom collection dependencies"

  # Merge default + explicitly defined collections
  yq -ys '{"collections": map(.collections[]) | unique_by(.name)}' ${TMPFILE}custom ${TMPFILE}base > ${TMPFILE}.yml

  # Now get the latest version of each collection
  [[ $Verbose == true ]] && echo "Lookup latest collection versions for ansible-core '$ansible_version'"
  ${DIRNAME}/ansible-collections-versions.py ${TMPFILE}.yml

  [[ $Verbose == true ]] && cat ${TMPFILE}.yml

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
Verbose=false
Dry_run=false
Echo=
Format=v2

Roledir=roles

# parse command line into arguments and check results of parsing
while getopts :a:c:dDf:hr:v-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    a|ansible-version)
      ansible_version_overwrite=$OPTARG
      ;;
    c|coldir)
      Coldir=$OPTARG
      ;;
    d|debug)
      Verbose=true
      set -vx
      ;;
    D|dry-run)
      Dry_run=true
      Dry_run1="-D"
      Echo=echo
      ;;
    f|format)
      Format=$OPTARG
      ;;
    h|help)
      Usage
      exit 0
      ;;
    r|roledir)
      Roledir=$OPTARG
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
  eval ${OPT}flag=1

done
shift $(($OPTIND -1))

# Get ansible version
ansible_version_full=$(ansible --version | grep ^ansible | sed -r "s/.*core //;s/\]//")
ansible_version_minor=$(echo $ansible_version_full | cut -f1,2 -d.)
export ansible_version=${ansible_version_overwrite:-$ansible_version_minor}

echo "ansible version = $ansible_version_full"

# Define list of collections
Collections_default
Collections_custom
Collections_merge

# Activate custom collections location
if [[ -n $Coldir ]]
then
  export ANSIBLE_COLLECTIONS_PATH=$Coldir
  Galaxy_args="-p $Coldir"
fi

# Install all collections
echo "Installing combined list of collections"
ansible-galaxy collection install $Galaxy_args -r ${TMPFILE}.yml

# Process playbook collections
if [[ -f collections/requirements.yml ]]
then
  echo "Installing collections from 'collections/requirements.yml'"
  ansible-galaxy collection install $Galaxy_args -r collections/requirements.yml
fi

# Exit cleanly
exit 0
