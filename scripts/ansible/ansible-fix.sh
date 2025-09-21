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

# task : tasks vars meta
TASKS="
Unnamed_tasks                  Y N N
Trailing_whitespace            Y Y Y
Missing_whitespace_variables   Y Y N
Missing_starting_whitespace    Y Y N
Comment_whitespacing           Y Y N
Jinja2_tests                   Y Y N
Line_ending                    Y Y Y
File_ending                    Y Y Y
Truthy                         Y Y Y
Jinja_spacing                  Y Y N
Name_casing                    Y N N
Include                        Y N N
Spaces_after_colon             Y Y N
"

# TASKS2SKIP="
# include
# include_tasks
# include_role
# import_playbook
# debug
# meta
# "

TASKS2SKIP=""

##############################################################
#
# Defining standarized functions
#
#############################################################

FUNCTIONS=${DIRNAME}/functions.sh
if [[ -f ${FUNCTIONS} ]]
then
   . ${FUNCTIONS}
else
   echo "Functions file '${FUNCTIONS}' could not be found!" >&2
   exit 1
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

Usage : $BASENAME <flags> <file-to-fix>

Flags :

   -d|--debug       : Debug mode (set -x)
   -D|--dry-run     : Dry run mode
   -h|--help        : Prints this help message
   -v|--verbose     : Verbose output

   -a|--all         : Run on all files in the current path recursively
   -e|--task <task> : Task to run (can be run multiple times)
   -s|--skip <task> : Task to skip (can be run multiple times)
   -t|type <type>   : Manually picks type of file (can be one of tasks, vars or meta)

Tasks:
`echo "$TASKS" | awk '{print $1}' | sed "s/^/  /"`

Examples:
Run scripts on all files within a directory tree
\$ $BASENAME -a

Run script on one specific molecule 'converge.yml'
\$ $BASENAME molecule/default/converge.yml

EOF

}

function Fix_file
{

  [[ $File =~ ^($Skip_files) ]] && return 0

  echo "Running 'ansible-fix.sh' on '$File'"

  # Identify file type based on name
  Type=${Type_overwrite:-""}
  # tasks
  [[ -z $Type && $File =~ ^([a-zA-Z0-9_-]+\.yml|playbooks/|tasks/|handlers/) ]] && Type=tasks
  [[ -z $Type && $File =~ ^(roles/[a-z_]+/tasks/|roles/[a-z_]+/handlers/) ]] && Type=tasks
  [[ -z $Type && $File =~ ^tests/(playbooks|test).yml ]] && Type=tasks
  [[ -z $Type && $File =~ ^(tasks-handlers/) ]] && Type=tasks
  # variables
  [[ -z $Type && $File =~ ^(host_vars/|group_vars/|vars/|defaults/) ]] && Type=vars
  [[ -z $Type && $File =~ ^(roles/[a-z_]+/vars/|roles/[a-z_]+/defaults/) ]] && Type=vars
  [[ -z $Type && $File =~ ^tests/vars.yml ]] && Type=vars
  # meta
  [[ -z $Type && $File =~ ^(meta/) ]] && Type=meta
  [[ -z $Type && $File =~ ^(roles/requirements.yml$) ]] && Type=meta
  [[ -z $Type && $File =~ ^(roles/[a-z_]+/meta/) ]] && Type=meta

  [[ -z $Type ]] && echo "Unable to identify type" >&2 && exit 1

  [[ $Verbose == true ]] && echo "Type = $Type"

  #
  exec 3<<<$TASKS
  while read -u3 Task Tasks Vars Meta
  do
    [[ -z $Task ]] && continue
    [[ $Task == \#* ]] && continue
    [[ $Task =~ ^($Skip_tasks)$ ]] && continue
    [[ -n $Execute_tasks && ! $Task =~ ^($Execute_tasks)$ ]] && continue 

    if [[ $Type == tasks && $Tasks == Y ]]
    then
      [[ $Verbose_level -ge 2 ]] && echo "Execute task '$Task'"
      eval $Task
      Compare
    fi

    if [[ $Type == vars && $Vars == Y ]]
    then
      [[ $Verbose_level -ge 2 ]] && echo "Execute task '$Task'"
      eval $Task
      Compare
    fi

    if [[ $Type == meta && $Meta == Y ]]
    then
      [[ $Verbose_level -ge 2 ]] && echo "Execute task '$Task'"
      eval $Task
      Compare
    fi

  done
  exec 3<&-

}


function Printf
{

  printf "%-40s%-10s\n" $1 $2

}

function Compare
{

  if cmp -s $File $TMPFILE
  then
    [[ $Verbose_level -ge 2 ]] && Printf $Task OK
  else
    Printf $Task Changed
    if [[ $Dry_run == true ]]
    then
      if [[ $Verbose == true ]]
      then
        diff $File $TMPFILE
      fi
    else
      cp $TMPFILE $File
    fi
  fi

}


function Unnamed_tasks
{

  # Create list of all modules
  ansible-doc --list 2>/dev/null | awk '{print $1}' | cut -f3 -d"." >${TMPFILE}0

  # Create list of all modules (FQCN)
  ansible-doc --list 2>/dev/null | awk '{print $1}' | sed -r "s/^([a-z0-9_]+)$/ansible.builtin.\\1/" >>${TMPFILE}0

  # Get lines that look like unnamed tasks
  grep -- "- [a-z0-9_\.]*:" $File | grep -v name: | sed "s/.*- //;s/:.*//" | sort -u > ${TMPFILE}1

  # Filter actual tasks
  Unnamed_tasks=`grep -x -f ${TMPFILE}0 ${TMPFILE}1`

  # Create working copy
  cp $File $TMPFILE

  # Replace each task
  for Task1 in $Unnamed_tasks
  do

    echo "$TASKS2SKIP" | sed "s/$/:/" | grep -q "^$Task1:" && continue

    Comment="TODO - EDIT THIS FIELD"

    if [[ $Task1 =~ (include|include_tasks)$ ]]
    then
      sed -i -r "s/(\s*)- ($Task1):(\s)*(.*)/\\1- name: include tasks '\\4'\\n  \\1\\2:\\3\\4/" $TMPFILE
    elif [[ $Task1 =~ (include_role)$ ]]
    then
      sed -i -r "s/(\s*)- ($Task1):(\s)*(.*)/\\1- name: include role '\\4'\\n  \\1\\2:\\3\\4/" $TMPFILE
    elif [[ $Task1 =~ (include_vars)$ ]]
    then
      sed -i -r "s/(\s*)- ($Task1):(\s)*(.*)/\\1- name: include vars '\\4'\\n  \\1\\2:\\3\\4/" $TMPFILE
    else
      Comment="TODO - EDIT THIS FIELD"
      sed -i -r "s/(\s*)- ($Task1):(\s)*(.*)/\\1- name: $Comment\\n  \\1\\2:\\3\\4/" $TMPFILE
    fi
  done

}

function Trailing_whitespace
{
  # Remove trailing whitespaces
  cp $File $TMPFILE
  sed -i -r "s/\s+$//" ${TMPFILE}
}

function Missing_whitespace_variables
{
  # Missing whitespace in variables
  cp $File $TMPFILE
  sed -i -r "s/\{\{([a-zA-Z0-9_])/{{ \1/g" $TMPFILE
  sed -i -r "s/([a-zA-Z0-9_)])\}\}/\1 }}/g" $TMPFILE
}

function Comment_whitespacing
{
  sed -r "s/([a-zA-Z0-9\:\-\_'\"\.]) # noqa/\1  # noqa/" $File > $TMPFILE
}

function Missing_starting_whitespace
{
  sed -r "s/^#([a-zA-Z0-9]+)/# \1/" $File > $TMPFILE
}

function Jinja2_tests
{
  # Replace jinja2 test in filter format
  cp $File $TMPFILE
  $DIRNAME/fix_test_syntax.py $TMPFILE
}

function File_ending
{
  # Fix missing line-ending on last file
  cp $File $TMPFILE
  cat -vte $TMPFILE | tail -1 | grep -q "\$$" || vim $TMPFILE -c 'wq'
}

function Line_ending
{
  sed "s/$//" $File > $TMPFILE
}

function Truthy
{
  cp $File $TMPFILE
  sed -ir "s/ True$/ true/" $TMPFILE
  sed -ir "s/ False$/ false/" $TMPFILE
}

function Jinja_spacing
{
  # Missing whitespace in variables
  cp $File $TMPFILE
  sed -i -r "s/([]a-z0-9'])(\+)/\\1 \\2/g;s/(\+)([[a-z0-9'])/\\1 \\2/g" $TMPFILE
  sed -i -r "s/([]a-z0-9'+])(\|)/\\1 \\2/g;s/(\|)([[a-z0-9'])/\\1 \\2/g" $TMPFILE
}

function Name_casing
{
  cp $File $TMPFILE
  sed -i -r "s/^(\s*)(- name:)(\s+)([a-z])/\\1\\2 \U\\4/" $TMPFILE
}

function Include
{
  cp $File $TMPFILE
  sed -i -r "s/^(\s*)(include:)/\\1include_tasks:/" $TMPFILE
}

function Spaces_after_colon
{
  cp $File $TMPFILE
  [[ $Type == tasks ]] && sed -i -r "s/(\s+)([a-zA-Z_]+:)(\s+)(.*)/\\1\\2 \\4/" $TMPFILE
  [[ $Type == vars ]] && sed -i -r "s/([a-zA-Z_]+:)(\s+)(.*)/\\1 \\3/" $TMPFILE
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

All=false
Skip_tasks="dummy"
Skip_files=".gitlab-ci.yml"

# parse command line into arguments and check results of parsing
while getopts :adDe:hs:S:t:v-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    a|all)
      All=true
      ;;
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
    e|task)
      Execute_tasks="$Execute_tasks|$OPTARG"
      ;;
    h|help)
      Usage
      exit 0
      ;;
    s|skip_tasks)
      Skip_tasks="$Skip_tasks|$OPTARG"
      ;;
    S|skip_files)
      Skip_files="$Skip_files|$OPTARG"
      ;;
    t|type)
      Type_overwrite=$OPTARG
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

  # Save all flags used, exept for '-a'
  if [[ ! ${OPT} =~ ^(a|all)$ ]]
  then
    Flags_used="$Flags_used -${OPT}"
  fi

done
shift $(($OPTIND -1))

if [[ $All == false && $# -eq 0 ]]
then
  Usage >&2
  exit 1
fi

# Get all files to fix
if [[ $All == true ]]
then
  Files=`find -P * -name \*.yml | grep -v molecule/`
else
  Files=`find -P "$@" -type f -name \*.yml`
fi

# Loop of all files
for File in $Files
do
  Fix_file $File
done
