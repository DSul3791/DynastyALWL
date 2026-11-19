#!/usr/bin/env bash
# Builds the Dynasty server image from this checkout (server/client split plan step C4). Runs on Linux or in Git Bash on Windows
# with Docker Desktop. deploy/server/SERVER.md has the whole route.
#   deploy/server/build_image.sh            a test image of this commit: dynasty-server:dev-<commit>, also tagged :latest. No build
#                                           stamp, so a game run from the editor (any commit) may join it.
#   deploy/server/build_image.sh --stamp    a release image: tools/build_stamp.py writes build_stamp.json (needs a full clone),
#                                           tagged dynasty-server:build-<N> and :latest. That server refuses every other build,
#                                           an editor run included (src/shared/build_stamp.gd).
set -euo pipefail
cd "$(dirname "$0")/../.."
PY=$(command -v python3 || command -v python || true)
COMMIT=$(git rev-parse HEAD)

if [ "${1:-}" = "--stamp" ]; then
	[ -n "$PY" ] || { echo "build_image: --stamp needs Python (tools/build_stamp.py)" >&2; exit 2; }
	"$PY" tools/build_stamp.py > /dev/null
	TAG="build-$("$PY" -c 'import json; print(json.load(open("build_stamp.json"))["build"])')"
elif [ -n "${1:-}" ]; then
	echo "build_image: unknown option $1 (only --stamp)" >&2; exit 2
else
	# A stamp left from an earlier release build would make this image refuse editor runs, and inside the image nothing shows it is old.
	[ ! -f build_stamp.json ] || { echo "build_image: build_stamp.json is left from a release build; delete it, or pass --stamp" >&2; exit 2; }
	TAG="dev-${COMMIT:0:8}"
fi

[ -z "$(git status --porcelain -- addons assets data scenes src worlds project.godot)" ] \
	|| echo "build_image: note: the game files have changes not committed; the image holds them, its label names $COMMIT" >&2

# Only BuildKit reads Dockerfile.dockerignore; the old builder would send everything, Dave's admin keys included.
export DOCKER_BUILDKIT=1
docker build -f deploy/server/Dockerfile --build-arg COMMIT="$COMMIT" -t "dynasty-server:$TAG" -t dynasty-server:latest .
MSYS_NO_PATHCONV=1 docker run --rm --entrypoint sh "dynasty-server:$TAG" -c '! [ -e /game/data/admin.json ] && ! [ -e /game/assets/animals ]' \
	|| { echo "build_image: the image holds data/admin.json or assets/animals; removing it" >&2; docker image rm "dynasty-server:$TAG" dynasty-server:latest; exit 1; }
echo "build_image: dynasty-server:$TAG (also :latest)"
