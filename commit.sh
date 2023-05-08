#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################

# Feedback; development.
ls -l

# Wait somewhere between 1 second and 1 day.
# sleep $(( ($(awk 'BEGIN { srand(); print int(rand()*32768) }' /dev/null) % 1440) * 60 + ($(awk 'BEGIN { srand(); print int(rand()*32768) }' /dev/null) % 60) ))

# Commit this repository.
apk add git
git clone https://github.com/jon-hawks/commitr.git
git status
echo git rm --cached commit.sh
echo git add commit.sh
echo git commit -m ""
echo git push
