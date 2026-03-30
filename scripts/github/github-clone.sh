#!/bin/bash

GITHUB_ROOT=/tmp/github
GIT_PROTOCOL=ssh
HTTPS_URL="https://github.com/\${org}/\${repo}"
SSH_URL="ssh://git@github.com/\${org}/\${repo}"
LIMIT=1000

rm -fr ${GITHUB_ROOT}

# Get all organization
orgs=$(gh org list | awk 'NR>0' | sort)

# Loop over all organization
for org in $orgs
do

  mkdir -p ${GITHUB_ROOT}/${org}
  cd ${GITHUB_ROOT}/${org}

  repos=$(gh repo list $org -L $LIMIT --json name | jq -r '.[] | .name' | sort)
  for repo in $repos
  do

    [[ ${repo} =~ shell_scripting ]] && continue

    echo "Repo '${org}/${repo}'"
    if [[ $GIT_PROTOCOL == ssh ]]
    then
      eval git clone -q "$SSH_URL"
    else
      eval git clone -q "$HTTPS_URL"
    fi
  done

  cd ${GITHUB_ROOT}
  tar -zcf ${org}.$(date +%Y%m%d).tgz $org

done
