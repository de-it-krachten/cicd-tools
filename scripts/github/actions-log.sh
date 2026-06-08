#!/bin/bash

set -vx

TMPFILE=$(mktemp)
REPO=de-it-krachten/$1
FILTER=$2

gh run list --repo $REPO --json status,conclusion,databaseId > $TMPFILE

status=$(jq -r '.[0].status' $TMPFILE)
state=$(jq -r '.[0].conclusion' $TMPFILE)
id=$(jq -r '.[0].databaseId' $TMPFILE)

# Cancel the specific queued run
gh run view $id --repo $REPO --log | grep $FILTER
