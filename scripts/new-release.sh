#!/usr/bin/env bash
set -euxo pipefail


ErrorReleaseExists=2
ErrorReleaseArgMissing=3

AppName=ExpoDiffApp
AppBaseBranch=app-base
ReleasesFile=RELEASES
ReadmeFile=README.md
ReadmeTable=README_TABLE.md
ReadmeTableBig=README_TABLE_BIG.md

NumberOfReleases=12 # the number of releases on the table

IgnorePaths=("README.md")

function guardMissingArg () {
    if [ "$#" -ne 1 ]; then
        echo "Release argument missing."
        exit "$ErrorReleaseArgMissing"
    fi
}

function guardExisting () {
    if grep -qFx "$newRelease" "$ReleasesFile"; then
        echo "Release $newRelease already exists!"
        exit "$ErrorReleaseExists"
    fi
}

function prepare () {
    # This git config setting, in combination with the `.gitattributes` file, tells the scripts to not pay attention to some files that don't need to be in the diffs, like the root `.gitignore` of this repo (not the RnDiffApp project).
    git config --local diff.nodiff.command true
    git pull
    pnpm install
}

function generateNewReleaseBranch () {
    # go to the base app branch
    git worktree add wt-app "$AppBaseBranch"
    cd wt-app

    # clear any existing stuff
    rm -rf "$AppName"

    git pull
    # make a new branch
    branchName=release/"$newRelease"
    git branch -D "$branchName" || true
    git checkout -b "$branchName"

    # generate app and remove generated git repo
    pnpx create-expo-app@latest "$AppName" --template blank@"$newRelease"

    # clean up before committing for diffing
    rm -rf "$AppName"/.git
    rm -rf "$AppName"/pnpm-lock.yaml

    # commit and push branch
    git add "$AppName"
    git commit -m "Release $newRelease"
    git push origin --delete "$branchName" || git push origin "$branchName"
    git push --set-upstream origin "$branchName" --tags

    # go back to master
    cd ..
    git clean -df # cleanup because rn init creates some yarn stuff but on the main directory
    rm -rf wt-app
    git worktree prune
}

function addReleaseToList () {
    echo "$newRelease" >> "$ReleasesFile"

    if command -v tac; then
        #   take each line ->dedup->    sort them              -> reverse them -> save them
        cat "$ReleasesFile" | uniq | xargs npx --silent semver | tac           > tmpfile
    else
        #   take each line ->dedup->    sort them              -> reverse them -> save them
        cat "$ReleasesFile" | uniq | xargs npx --silent semver | tail -r       > tmpfile
    fi

    mv tmpfile "$ReleasesFile"
}

function generateDiffs () {
    if [ ! -d wt-diffs ]; then
        git worktree add wt-diffs diffs
    fi

    cd wt-diffs
    git pull
    cd ..

    IFS=$'\n' GLOBIGNORE='*' command eval 'releases=($(cat "$ReleasesFile"))'
    for existingRelease in "${releases[@]}"
    do
        if [ "$existingRelease" == "$newRelease" ]; then
            continue
        fi

        if ./scripts/compare-releases.js "$existingRelease" "$newRelease"; then
            continue
        fi

        ignoreArgs=()
        for path in "${IgnorePaths[@]}"; do
            ignoreArgs+=(":!$path")
        done

        git diff --binary -w -M15% origin/release/"$existingRelease"..origin/release/"$newRelease" \
            -- . "${ignoreArgs[@]}" > wt-diffs/diffs/"$existingRelease".."$newRelease".diff
    done

    cd wt-diffs
    git add .
    git commit -m "Add release $newRelease diffs" || true
    git push
    cd ..
}

function pushMaster () {
    git add .
    git commit -m "Add release $newRelease"
    git push
}

function generateTable () {
    head -n "$NumberOfReleases" "$ReleasesFile" | ./scripts/generate-table.js > "$ReadmeTable"
}

function generateBigTable () {
    cat "$ReleasesFile" | ./scripts/generate-table.js --big > "$ReadmeTableBig"
}

ReadmeHeader=README_HEADER.md
ReadmeFooter=README_FOOTER.md

function breakUpReadme () {
    perl -p0e 's/(.*## Diff table[^\n]*\n\n)(.*)/$1/smg' "$ReadmeFile" > "$ReadmeHeader"
    perl -p0e 's/(.*)(\n## To see.*)/$2/smg' "$ReadmeFile" > "$ReadmeFooter"
}

function makeUpReadme () {
    cat "$ReadmeHeader" "$ReadmeTable" "$ReadmeFooter" > "$ReadmeFile"
}

function generateReadme () {
    breakUpReadme
    makeUpReadme
}

function generateGHPages () {
    cp docs/_index.html docs/index.html
    pnpm markdown "$ReadmeTableBig" >> docs/index.html
}

function cleanUp () {
    rm -rf "$ReadmeHeader" "$ReadmeFooter" "$ReadmeTable" "$ReadmeTableBig"
    rm -rf wt-app
    git worktree prune
}


guardMissingArg $*
newRelease=${1#v}

guardExisting

prepare
generateNewReleaseBranch
addReleaseToList
generateDiffs

generateTable
generateReadme

generateBigTable
generateGHPages

cleanUp
pushMaster
