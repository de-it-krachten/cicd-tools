#!/bin/bash

TMPFILE=$(mktemp).j2

trap 'rm -f ${TMPFILE}*' EXIT

# jinjanator

export xxx='["a","b","c"]'

cat <<EOF > $TMPFILE
[
  {%- for x in xxx | from_json %}
  {{ x }}{{ ',' if not loop.last }}
  {%- endfor %}
]
EOF

jinjanate $TMPFILE


# e2j2
export xxx='json:["a","b","c"]'

cat <<EOF > $TMPFILE
[
  {%- for x in xxx %}
  {{ x }}{{ ',' if not loop.last }}
  {%- endfor %}
]
EOF

e2j2 -f $TMPFILE
cat ${TMPFILE%%.j2}
