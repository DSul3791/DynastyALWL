#!/bin/bash
# usage: pubcheck.sh DIR  -> fails if any two pictures in DIR/shots are byte-identical
D="$1/shots"; d=$(md5sum "$D"/*.png 2>/dev/null | awk '{print $1}' | sort | uniq -d)
if [ -n "$d" ]; then echo "DUPLICATE pictures:"; md5sum "$D"/*.png | grep -F "$d"; exit 1; fi; echo "pictures all differ"
