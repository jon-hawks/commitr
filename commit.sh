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
echo "https://x-access-token:$GITHUB_TOKEN@github.com/$GITHUB_REPO.git"
git clone --depth 1 --no-tags --single-branch "https://x-access-token:$GITHUB_TOKEN@github.com/$GITHUB_REPO.git"
cd commitr || exit 1

# Commit a file.
git config user.email "17555162+jon-hawks@users.noreply.github.com"
git config user.name "Jon Hawks"
git commit --allow-empty -m "Update at: $(date '+%F %H:%M:%S %Z')."
git push
