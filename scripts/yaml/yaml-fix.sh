#!/bin/bash

TMPFILE=$(mktemp)

trap 'rm -f ${TMPFILE}*' EXIT

find ${1:-'.'} -type f -name \*.yml > $TMPFILE

exec 3<$TMPFILE
while read -u3 file
do

  # trailing whitespaces
  sed -i -r 's/\s+$//' $file

  # multiple whitespace after ':'
  # sed -i "s/:  */: /g" $file

  # multiple whitespace after' ','
  # sed -i "s/,  */, /g" $file

done
exec 3<&-
