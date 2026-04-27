#!/bin/bash

PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH
BASENAME=$(basename $(readlink -f $0))
DIRNAME=$(dirname $(readlink -f $0))
BASENAME_ROOT=${BASENAME%%.*}
HOSTNAME=$(hostname -f)
TMPFILE=$(mktemp)
CONFIGFILE=${DIRNAME}/ansible.yml
TEMPLATEFILE=${DIRNAME}/ansible.yml.j2

VENV_LIST_DEFAULT="
yq
e2j2
jinjanator
pproxy
docker-squash
ansible-navigator
ansible9
ansible11
ansible12
ansiblecore216
ansiblecore218
ansiblecore219
awxkit
"

VENV_LIST=${VENV_LIST:-$VENV_LIST_DEFAULT}


function Print_separator
{
  printf "%80s\n" | tr ' ' '-'
}

function Jinjanator
{

  venv=${root_dir}/jinjanator

  $sudo python3 -m venv $venv
  $sudo $venv/bin/pip3 install pip wheel setuptools --upgrade
  $sudo $venv/bin/pip3 install jinjanator jinjanator-plugin-ansible
  $sudo ln -fs $venv/bin/jinjanate /usr/local/bin/jinjanate

}

function Template
{

  if [[ -f ${TEMPLATEFILE} ]]
  then
    $sudo jinjanate ${TEMPLATEFILE} --quiet -o ${CONFIGFILE}
  fi

}

function Venv
{

  Print_separator
  echo "$venv"
  Print_separator
  echo "$sudo ${DIRNAME}/python.sh $Verbose1 -c ${DIRNAME}/ansible.yml -p $venv -V $root_dir/$venv"
  Print_separator
  $sudo ${DIRNAME}/python.sh $Verbose1 -c ${DIRNAME}/ansible.yml -p $venv -V $root_dir/$venv
  $sudo rm -fr $root_dir/$venv/lib/python3.*/site-packages/selinux

}


# parse command line into arguments and check results of parsing
while getopts :dhsv-: OPT
do

  # Support long options
  if [[ $OPT = "-" ]] ; then
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi

  case $OPT in
    d|debug)
      Verbose=true
      set -vx
      ;;
    h|help)
      Usage
      exit 0
      ;;
    s|sudo)
      sudo=sudo
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

root_dir=$1

if [[ -z $root_dir ]]
then
  echo "Usage   : $0 <venv-root-dir>" >&2
  echo "Example : $0 /usr/local/venv" >&2
  exit 1
fi

# Setup jinjanator
Jinjanator

# Create from template
Template

# Setup generic
for venv in $VENV_LIST
do
  Venv
done
