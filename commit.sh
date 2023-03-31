#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################
git rm --cached commit.sh
git add commit.sh
git commit -m ""
git push
