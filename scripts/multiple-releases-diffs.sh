#!/usr/bin/env bash
set -euxo pipefail

releases=(
50
49
48
)


if [ ! -d wt-diffs ]; then
  git worktree add wt-diffs diffs
fi

for vfrom in "${releases[@]}"
do
  echo "from $vfrom"
  for vto in "${releases[@]}"
  do
    if [ "$vfrom" == "$vto" ]; then
      continue
    fi

    if ./scripts/compare-releases.js "$vfrom" "$vto"; then
      continue
    fi

    git diff --binary -w -M15% origin/release/"$vfrom"..origin/release/"$vto" > wt-diffs/diffs/"$vfrom".."$vto".diff
  done
done
