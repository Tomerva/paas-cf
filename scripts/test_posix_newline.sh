#!/bin/bash
RET_CODE=0

echo "${0#$PWD}" >> ~/.paas-script-usage

test_posix_newline() {
  if [ -L "$1" ]; then
    RET_CODE=0
    return
  fi
  if [ ! -f "$1" ]; then
    echo "$1 is not a regular file" 1>&2
    RET_CODE=1
    return
  fi
  if [ ! -r "$1" ]; then
    echo "File $1 not found or not readable" 1>&2
    RET_CODE=1
    return
  fi
  if grep -Iq . "$1" ; then
    final_char=$(tail -q -c 1 "$1")
    if [ "${final_char}" != "" ]; then
      echo "$1 has not POSIX trailing new line" 1>&2
      RET_CODE=1
    fi
  fi
}

set -e
for i in "$@"; do
  test_posix_newline "$i"
done
exit $RET_CODE
