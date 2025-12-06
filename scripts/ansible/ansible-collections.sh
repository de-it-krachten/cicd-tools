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

[[ -x /usr/local/bin/e2j2 ]] && E2J2=/usr/local/bin/e2j2 || E2J2=e2j2
[[ -x /usr/local/bin/yq ]] && YQ=/usr/local/bin/yq || YQ=yq


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
while getopts :c:dDf:hr:v-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
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

# For specific ansible versions, fallback onto old Galaxy
Galaxy_legacy

# Get ansible version
ansible_version_full=$(ansible --version | grep ^ansible | sed -r "s/.*core //;s/\]//")
ansible_version_minor=$(echo $ansible_version_full | cut -f1,2 -d.)
export ansible_version=$ansible_version_minor

echo "ansible version = $ansible_version_full"

# Write all generic requirements
cat <<EOF >${TMPFILE}base.j2
---
collections:
  - ansible.posix
  - ansible.windows
  - name: community.docker
{%- if ansible_version | regex_search('2.16') %}
    version: "<5.0.0"
{%- else %}
    version: "*"
{%- endif %}
  - name: community.general
{%- if ansible_version == '2.15' %}
    version: ">10,<11"
{%- elif ansible_version == '2.16' %}
    version: ">11,<12"
{%- else %}
    version: "*"
{%- endif %}
  - community.windows
EOF

# Create basic collections from template
e2j2 -f ${TMPFILE}base.j2 >/dev/null 2>&1

# Get all collection files
Collection_files=$(ls .collections ${Roledir}/*/.collections ${TMPFILE}base 2>/dev/null)

# Get all collections
Collections=$($YQ .collections $Collection_files | jq -s 'add|sort|unique' | jq -jc 'del(.[] | nulls)')
export collections="json:$Collections"

# Create collection using jinja2 template
if [[ $Format == v1 ]]
then
  echo "Creating jinja template (v1)"
  cat <<EOF > ${TMPFILE}.j2
---
{% if collections | length > 0 %}
collections:
{% for collection in collections %}
{% if collection | type_debug == 'dict' %}
{% if collection.version is defined %}
- {{ collection.name }}:{{ collection.version }}
{% else %}
- {{ collection.name }}
{% endif %}
{% else %}
- {{ collection }}
{% endif %}
{% endfor %}
{% else %}
collections: []
{% endif %}
EOF
else
  echo "Creating jinja template (v2)"
  export collections="json:$Collections"
  export ansible_version=$__ansible_version
  cat <<EOF > ${TMPFILE}.j2
---
{% if collections | length > 0 %}
collections:
{% for collection in collections %}
{% if collection != 'ansible.builtin' %}
{% if collection | type_debug == 'dict' %}
{% if not ansible_version | regex_search('^(2\.9)$') %}
- {{ collection }}
{% endif %}
{% else %}
{% set name = (collection | regex_replace(':.*')) %}
{% set version = (collection | regex_replace('.*:')) %}
- name: {{ name }}
{% if version != collection %}
  version: {{ version }}
{% endif %}
{% endif %}
{% endif %}
{% endfor %}
{% else %}
collections: []
{% endif %}
EOF
fi

# Exit if templating fails
echo "Creating collections file from template"
if $E2J2 -f ${TMPFILE}.j2 >/dev/null 2>&1
then
  yq -y . ${TMPFILE} > ${TMPFILE}.yml
else
  cat ${TMPFILE}.err >&2
  exit 1
fi

# Display list of collections
echo "Showing collections to install"
cat ${TMPFILE}.yml

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
