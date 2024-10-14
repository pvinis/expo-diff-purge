#!/usr/bin/env bash
set -euxo pipefail

releases=(
31
32
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
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
