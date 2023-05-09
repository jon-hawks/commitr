#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################

# Wait somewhere between 1 second and 1 day.
# sleep $(( ($(awk 'BEGIN { srand(); print int(rand() * 32768) }' /dev/null) % 1440) * 60 + ($(awk 'BEGIN { srand(); print int(rand() * 32768) }' /dev/null) % 60) ))
sleep 30

# Install Git.
apk add --no-cache git

# Clone this repository.
git clone --depth 1 --no-tags --single-branch "https://$GITHUB_TOKEN:@github.com/$GITHUB_REPO.git"
cd commitr || exit 1

# Commit a file.
git commit --allow-empty -m "Update at: $(date '+%F %H:%M:%S %Z')."
git push
