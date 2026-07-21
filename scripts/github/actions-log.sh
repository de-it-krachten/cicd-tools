#!/bin/bash

set -vx

TMPFILE=$(mktemp)

REPO=${1:-$(basename $PWD)}
FILTER=$2


gh run list --repo $GH_ORG/$REPO --json status,conclusion,databaseId > $TMPFILE

status=$(jq -r '.[0].status' $TMPFILE)
state=$(jq -r '.[0].conclusion' $TMPFILE)
id=$(jq -r '.[0].databaseId' $TMPFILE)

# Cancel the specific queued run
gh run view $id --repo $GH_ORG/$REPO --log | cat
