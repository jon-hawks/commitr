#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################
ls -l
git status
sleep $(( ($RANDOM % 1440) * 60 + ($RANDOM % 60) ))
echo git rm --cached commit.sh
echo git add commit.sh
echo git commit -m ""
echo git push
