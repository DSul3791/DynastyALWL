#!/bin/bash
# Prints the next free build number (advice only: the Technical Director renumbers at merge). Run from the repo root.
LOG=${BUILD_LOG:-docs/mirror/tech/BUILD_LOG.md}   # the copy in the repo; the old shared folder is not needed
HERE=$(grep -o 'NUMBER := [0-9]*' src/shared/build.gd | grep -o '[0-9]*')
LOGGED=$(grep -o '^- [0-9:]* [A-Za-z_]*: [0-9]*' "$LOG" 2>/dev/null | awk '{print $NF}' | sort -n | tail -1)
echo $(( ( ${HERE:-0} > ${LOGGED:-0} ? ${HERE:-0} : ${LOGGED:-0} ) + 1 ))
