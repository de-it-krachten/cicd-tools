#!/bin/bash

SEMREL_CONFIG=.releaserc.yml
BRANCHES="['master','main']"

# parse command line into arguments and check results of parsing
while getopts :BdDhv-: OPT
do    
  
  case $OPT in
    B)
      Branch="$CI_COMMIT_BRANCH"
      Branch1="--branches $Branch"
      ;;
    d|debug)
      set -vx
      Verbose=true
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

# Write semantic-release configuration file 
if [[ ! -f $SEMREL_CONFIG ]]
then
  Configfile_created=true
  cat <<EOF > $SEMREL_CONFIG
---
branches: $BRANCHES
plugins:
  - '@semantic-release/commit-analyzer'
  - '@semantic-release/release-notes-generator'
  - '@semantic-release/changelog'
  - '@semantic-release/gitlab'
  - ["@semantic-release/git", {
      "assets": ["CHANGELOG.md"],
      "message": "chore(release): \${nextRelease.version} [skip ci]\\n\\n\${nextRelease.notes}"
    }]
EOF
fi

# Execute sematic-release
semantic-release $Branch1 $SEMREL_ARGS || Errors=$(( $Errors + 1 ))

# Delete the configuration file
[[ $Configfile_created == true ]] && rm -f $SEMREL_CONFIG

# Exit
exit ${Errors:-0}
