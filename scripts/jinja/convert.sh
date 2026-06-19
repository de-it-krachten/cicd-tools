#!/bin/bash

TMPFILE=$(mktemp)
TEST=false

trap 'rm -f ${TMPFILE}*' EXIT

if [[ $1 == --test ]]
then
  cat <<EOF > $TMPFILE
{% for x in [ 'a', 'b', 'c' ] %}
{{ x }}
{% endfor %}
EOF
  TEST=true
  set -- $TMPFILE
fi

if [[ $# -lt 1 ]]
then
  echo "Usage : $0 <file1> <file2> ... <fileN>" >&2
  exit 1
fi

while [[ $@ != "" ]]
do

  [[ -L $1 ]] && shift && continue

  # Convert jinja
  cp "$1" ${TMPFILE}1
  sed -i "s/{{/<=/g" ${TMPFILE}1
  sed -i "s/}}/=>/g" ${TMPFILE}1
  sed -i "s/{%/<%/g" ${TMPFILE}1
  sed -i "s/%}/%>/g" ${TMPFILE}1

  diff "$1" ${TMPFILE}1 >/dev/null 2>&1 && shift && continue

  echo "Converting '$1'"
  cp ${TMPFILE}1 "$1"

  shift

done

[[ $TEST == true ]] && cat $TMPFILE
