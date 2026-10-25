#!/bin/bash
# no CPU pinning (Dave 25 Oct): drop "-c LIST" and run the command as given
if [ "$1" = "-c" ]; then shift 2; fi
exec "$@"
