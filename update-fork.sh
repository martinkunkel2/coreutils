#!/bin/bash
set -eu

branch=$(git branch --show-current)

git fetch --all

git checkout main
git pull
git rebase upstream/main
git push -f

git checkout $branch
git pull
git rebase origin/main
git push -f
