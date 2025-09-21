#!/bin/bash -e

GIT_ROOT=/tmp/git

[[ ! -d $GIT_ROOT ]] && mkdir -p $GIT_ROOT
cd $GIT_ROOT

gh repo list de-it-krachten -L 50 --json name,isFork | \
jq -r '.[] | select(.isFork==false) | select(.name|test("ansible-role-")) | .name' | sort | \
while read repo
do
  if [[ -d ${repo} ]]
  then
    echo "Pull '$repo'"
    cd ${repo} 
    git pull -q
    cd - >/dev/null
  else
    echo "Clone '$repo'"
    git clone -q git@github.com:de-it-krachten/${repo}.git
  fi

done
