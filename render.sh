#!/bin/bash

TMPFILE=$(mktemp)
trap 'rm -f ${TMPFILE}*' EXIT

# Get all files
files=$(find . -name \*template -type f)

# Render all files
for file in $files
do
  file1=${file%%.template}
  sed -r "s/^  *<%/<%/" $file > $TMPFILE
  if diff $TMPFILE $file1 >/dev/null 2>&1
  then
    :
  else
    # diff $TMPFILE $file1
    echo "Updating '$file1'"
    cp $TMPFILE $file1
  fi
done

