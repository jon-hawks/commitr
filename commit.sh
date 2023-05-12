#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################

# Wait somewhere between 1 second and 1 day.
TIMER=$(shuf -i 1-86400 -n 1)
while [ "$TIMER" -gt 0 ]; do
    echo "Committing in $TIMER seconds."
    sleep 1
    TIMER=$((TIMER - 1))
done

# Install Git.
apk add --no-cache git openssh

# Configure Git.
mkdir -p ~/.ssh
echo "$GIT_KEY" | base64 -d > ~/.ssh/id_rsa
chmod 400 ~/.ssh/id_rsa
ssh-keyscan github.com > ~/.ssh/known_hosts
git config --global user.email "$GIT_EMAIL"
git config --global user.name "$GIT_USER"
git config --global core.sshCommand "ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes"

# Clone this repository.
git clone --depth 1 --no-tags --single-branch "ssh://git@github.com/$GITHUB_REPO.git"
cd commitr || exit 1

# Commit a file.
git commit --allow-empty -m "Update at: $(date '+%F %H:%M:%S %Z')."
git push
