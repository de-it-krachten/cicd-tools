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

   -d|--debug           : Debug mode (set -x)
   -D|--dry-run         : Dry run mode
   -h|--help            : Prints this help message
   -v|--verbose         : Verbose output

   -o|--output <file>   : File to write output to
   -s|--string <string> : Block & variable identifiers to use (e.g. '{{', '<=')

EOF

}

function Config
{

  case $String in
    '{{')
       variable_start_string="{{"
       variable_end_string="}}"
       block_start_string="{%"
       block_end_string="%}"
       ;;
    '<=')
       variable_start_string="<="
       variable_end_string="=>"
       block_start_string="<%"
       block_end_string="%>"
       ;;
    '<<')
       variable_start_string="<<"
       variable_end_string=">>"
       block_start_string="<%"
       block_end_string="%>"
       ;;
    *)
      echo "Unknown string '$String' used" >&2
      exit 1
      ;;
  esac

  cat <<EOF > ${TMPFILE}.py
#
# Example customization.py file for jinjanator
# Contains hooks that modify the way Jinja2 is initialized and used

def j2_environment_params():
    """ Extra parameters for the Jinja2 Environment """
    # Jinja2 Environment configuration
    # https://jinja.pocoo.org/docs/2.10/api/#jinja2.Environment
    return dict(
        # Just some examples

        # Change block start/end strings
        block_start_string='$block_start_string',
        block_end_string='$block_end_string',
        # Change variable strings
        variable_start_string='$variable_start_string',
        variable_end_string='$variable_end_string',
        # Remove whitespace around blocks
        trim_blocks=True,
        lstrip_blocks=True,
        # Enable line statements:
        # http://jinja.pocoo.org/docs/2.10/templates/#line-statements
        line_statement_prefix='#',
        # Keep \n at the end of a file
        keep_trailing_newline=True,
        # Enable custom extensions
        # http://jinja.pocoo.org/docs/2.10/extensions/#jinja-extensions
        extensions=('jinja2.ext.i18n',),
    )
EOF

}

function Template
{

  [[ -n $Output ]] && Args="--output-file $Output"
  
  jinjanate $Args --customize ${TMPFILE}.py $Template $Varsfile

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

String="{{"

# parse command line into arguments and check results of parsing
while getopts :dDho:s:v-: OPT
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
      Verbose1="-v"
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
    o|output)
      Output=$OPTARG
      ;;
    s|string)
      String="$OPTARG"
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

Template=$1
Varsfile=$2

Config
Template

# Now exit
exit 0
