#!/bin/bash -e

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
WORKINGDIR=$(/usr/bin/pwd)

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

GH_ORG=${GH_ORG:-"Automation-Erfpacht"}
GH_REPO="$(basename $(/usr/bin/pwd))"
GH_TYPE=${GH_TYPE:-"internal"}


##############################################################
#
# Defining standarized functions
#
#############################################################

#FUNCTIONS=${DIRNAME}/functions.sh
#if [[ -f ${FUNCTIONS} ]]
#then
#   . ${FUNCTIONS}
#else
#   echo "Functions file '${FUNCTIONS}' could not be found!" >&2
#   exit 1
#fi


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

   -A|--access <type> : Access - private/internal/public (default=$GH_TYPE)
   -C|--no-init-ci    : Do not setuo CI
   -F|--force         : Force creation/initializaation
   -i|--internal      : Setup epo as 'internal'
   -I|--no-init       : Do not initialize repo
   -o|--org <org>     : Github organization (default=$GH_ORG)
   -p|--private       : Setup private repo
   -P|--path <path>   : Set alternative path (default=current path)
   -r|--repo <repo>   : Repository name (default=$GH_REPO)
   -S|--stage2        : Stage2 only

EOF

}

function Create_repo
{

  gh repo create ${Org}/${Repo} ${Gh_args}
  git init
  git remote add origin https://github.com/${Org}/${Repo}.git
  git branch -M main

}

function Init_repo
{
  [[ ! -f README.md ]] && echo "# $Repo" > README.md
  git add README.md
  git commit -m "First commit"
  git push -u origin main
  git branch -M dev

}


function Init_ci
{

  case $(basename $WORKINGDIR) in
    ansible-role-*)
      $DIRNAME1/ci-init.sh -m role -i
      ;;
    ansible-playbooks-*)
      $DIRNAME1/ci-init.sh -m playbook -i
      ;;
  esac

}

function Update
{

  case $(basename $WORKINGDIR) in
    ansible-role-*)
      $DIRNAME1/ci-init.sh -m role -iF
      $DIRNAME1/ci-init.sh -m role
      $DIRNAME1/readme.sh
      ;;
    ansible-playbook-*)
      /$DIRNAME1/ci-init.sh -m playbook -i
      ;;
  esac

}

function Commit
{

  git add .
  git add README.md
  git commit -m "Initial commit"
  git push -u origin dev -f

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
Stage=1
Repo_type=$GH_TYPE
Init_repo=true
Init_ci=true

# parse command line into arguments and check results of parsing
while getopts :CdDFhiIo:pP:r:Sv-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    C|no-init-ci)
      Init_ci=false
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
    F|force)
      Force=true
      ;;
    h|help)
      Usage
      exit 0
      ;;
    i|internal)
      Repo_type=internal
      ;;
    I|no-init)
      Init_repo=false
      ;;
    o|org)
      Org=$OPTARG
      ;;  
    p|private)
      Repo_type=private
      ;;
    P|path)
      Path=$OPTARG
      ;;
    r|repo)
      Repo=$OPTARG
      ;;
    S|stage2)
      Stage=2
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

done
shift $(($OPTIND -1))

Repo_type=${Repo_type:-$GH_TYPE}
Org=${Org:-$GH_ORG}
Repo=${Repo:-$GH_REPO}
Gh_args="--${Repo_type}"

echo "organization: $Org"
echo "repository:   $Repo"
echo "visibility:   $Repo_type"
echo "init repo:    $Init_repo"
echo "init ci:      $Init_ci"

sleep 5

[[ -n $Path ]] && cd $Path

if [[ $Stage == 1 ]]
then
  if gh repo view $Org/$Repo >/dev/null 2>&1
  then
    if [[ $Force == true ]]
    then
      rm -fr .git
      gh repo delete ${Org}/${Repo} --yes
    else
      echo "Repo already present on Github!" >&2
      exit 1
    fi
  fi

  Create_repo
  [[ $Init_repo == true ]] && Init_repo
  [[ $Init_ci == true ]] && Init_ci

else
  Update
  Commit
fi
