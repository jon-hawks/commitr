#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################

# Debugging; feedback.
echo "$(echo "$GIT_KEY" | base64 -d)"

# Wait somewhere between 1 second and 1 day.
# sleep $(( ($(awk 'BEGIN { srand(); print int(rand() * 32768) }' /dev/null) % 1440) * 60 + ($(awk 'BEGIN { srand(); print int(rand() * 32768) }' /dev/null) % 60) ))
sleep 30

# Install Git.
apk add --no-cache git openssh

# Configure Git.
git config --global user.email "$GIT_EMAIL"
git config --global user.name "$GIT_USER"
git config --global core.sshCommand "echo \"$(echo "$GIT_KEY" | base64 -d)\" | ssh -i /dev/stdin -o IdentitiesOnly=yes"
ssh-keyscan github.com > ~/.ssh/known_hosts

# Clone this repository.
mkdir -p ~/.ssh
git clone --depth 1 --no-tags --single-branch "ssh://git@github.com/$GITHUB_REPO.git"
cd commitr || exit 1

# Commit a file.
git commit --allow-empty -m "Update at: $(date '+%F %H:%M:%S %Z')."
git push
