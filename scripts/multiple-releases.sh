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
)

for v in "${releases[@]}"
do
    echo $v
    ./scripts/new-release.sh $v
done
