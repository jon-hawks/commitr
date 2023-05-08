#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################

# Feedback; development.
pwd
ls -l

# Wait somewhere between 1 second and 1 day.
# sleep $(( ($(awk 'BEGIN { srand(); print int(rand()*32768) }' /dev/null) % 1440) * 60 + ($(awk 'BEGIN { srand(); print int(rand()*32768) }' /dev/null) % 60) ))

# Install Git.
apk add --no-cache git

# Clone this repository.
git clone --depth 1 --no-tags --single-branch https://github.com/jon-hawks/commitr.git
cd commitr || exit 1

# Commit a file.
git status
echo git rm --cached commit.sh
echo git add commit.sh
echo git commit -m ""
echo git push
