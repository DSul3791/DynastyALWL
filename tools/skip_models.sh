#!/usr/bin/env bash
# Leaves the bought animal models (assets/animals, Git LFS since 23 Nov 2026) out of this clone: test clones, cloud sessions, Lane B and CI
# need none of them, and each full download is about 2.6 GB of the free 10 GiB a month of LFS downloads. The folder is then absent, as it was
# before the models were in the repository, so the game draws its code-built animals (data/animals/models.json) and Godot never meets an
# LFS pointer stub. Run once in a clone, best one made with GIT_LFS_SKIP_SMUDGE=1 (so nothing is downloaded at all):
#   GIT_LFS_SKIP_SMUDGE=1 git clone <url> && cd DynastyALWL && tools/skip_models.sh
# Undo (to get the models): git sparse-checkout disable && git config --unset lfs.fetchexclude && git lfs pull
# It sets repository-wide git config: run it in the main clone, not in a worktree of a clone that should keep the models.
set -e
cd "$(git rev-parse --show-toplevel)"
git config lfs.fetchexclude 'assets/animals/**'
git sparse-checkout set --no-cone '/*' '!/assets/animals/'
if [ -e assets/animals ]; then
	echo "skip_models: assets/animals is still here (files git does not track?); look in it before deleting anything" >&2
	exit 1
fi
echo "skip_models: assets/animals left out of this clone (no LFS download, code-built animals)"
