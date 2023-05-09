#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################

# Wait somewhere between 1 second and 1 day.
# sleep $(( ($(awk 'BEGIN { srand(); print int(rand()*32768) }' /dev/null) % 1440) * 60 + ($(awk 'BEGIN { srand(); print int(rand()*32768) }' /dev/null) % 60) ))

# Install Git.
apk add --no-cache git

# Clone this repository.
printenv
git clone --depth 1 --no-tags --single-branch "https://$GITHUB_TOKEN@github.com/$GITHUB_REPO.git"
cd commitr || exit 1

# Commit a file.
git status
git rm --cached commit.sh
git status
git add commit.sh
git status
git commit -m "Update commit script."
git status
echo git push
