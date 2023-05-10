#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################

# Wait somewhere between 1 second and 1 day.
# sleep $(( ($(awk 'BEGIN { srand(); print int(rand() * 32768) }' /dev/null) % 1440) * 60 + ($(awk 'BEGIN { srand(); print int(rand() * 32768) }' /dev/null) % 60) ))
sleep 30

# Install Git.
apk add --no-cache git openssh

# Clone this repository.
ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --depth 1 --no-tags --single-branch "ssh://git@github.com/$GITHUB_REPO.git"
cd commitr || exit 1

# Configure Git.
echo \"$(echo "$GIT_KEY" | base64 -d)\"
git config core.sshCommand "echo \"$(echo "$GIT_KEY" | base64 -d)\" | ssh -i /dev/stdin -o IdentitiesOnly=yes"
git config user.email "$GIT_EMAIL"
git config user.name "$GIT_USER"

# Commit a file.
git commit --allow-empty -m "Update at: $(date '+%F %H:%M:%S %Z')."
git push
