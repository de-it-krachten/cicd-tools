#!/bin/bash

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

  if [[ $Verbosity_level -gt 1 ]]
  then
    echo "================================" >&2
    echo "Default collections" >&2
    echo "================================" >&2
    cat ${TMPFILE}base >&2
  fi

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
  Collection_files=$(ls .collections ${Roledir}/*/.collections collections/requirements.yml 2>/dev/null)

  # Convert all collections
  Files_merge $Collection_files | yq -y . > ${TMPFILE}custom

  # Strip amsterdam
  sed -i '/name: amsterdam\./d' ${TMPFILE}custom

  if [[ $Verbosity_level -gt 1 ]]
  then
    echo "================================" >&2
    echo "Custom collections" >&2
    echo "================================" >&2
    cat ${TMPFILE}custom >&2
  fi

}

function Collections_merge
{

  [[ $Verbose == true ]] && echo "Merge default and custom collection dependencies"

  # Merge default + explicitly defined collections
  yq -ys '{"collections": map(.collections[]) | unique_by(.name)}' ${TMPFILE}custom ${TMPFILE}base > ${TMPFILE}.yml

  # Now get the latest version of each collection
  [[ $Verbose == true ]] && echo "Lookup latest collection versions for ansible-core '$ansible_version'"
  ${DIRNAME}/ansible-collections-versions.py ${TMPFILE}.yml

  if [[ $Verbosity_level -gt 1 ]]
  then
    echo "================================" >&2
    echo "Merged collections" >&2
    echo "================================" >&2
    cat ${TMPFILE}.yml | yq -y . >&2
  fi

}

function Collections_fix
{

  sed -i "s/: 1\.0\.0/: v1.0.0/" ${TMPFILE}.yml

}

function Files_merge
{

  yaml_files="$@"

  # Convert collections v1 -> v2 and into json
  for f in $yaml_files
  do

    $DIRNAME/ansible-convert-collections.py $f | yq -j . > ${f}.json
    json_files="$json_files ${f}.json"

  done

  # Merge all json files
  jq -s 'reduce .[] as $file ({}; .collections += ($file.collections // [])) | .collections |= unique_by(.name)' $json_files

  # Delete files
  rm -f $json_files

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
      Verbosity_level=$((Verbosity_level+1))
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
Collections_fix

# Activate custom collections location
if [[ -n $Coldir ]]
then
  export ANSIBLE_COLLECTIONS_PATH=$Coldir
  Galaxy_args="-p $Coldir"
fi

# Install all collections
echo "Installing combined list of collections"
if [[ $Verbose == true ]]
then
  ansible-galaxy collection install $Galaxy_args -r ${TMPFILE}.yml
else
  ansible-galaxy collection install $Galaxy_args -r ${TMPFILE}.yml >/dev/null
fi

# Exit cleanly
exit 0
