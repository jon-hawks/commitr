#!/bin/sh
################################################################################
# A script that commits itself.                                                #
################################################################################

# Add randomization.
while true; do

    # Wait somewhere between 1 second and 1 day.
    sleep "$(shuf -i 1-86400 -n 1)"

    # Only execute sometimes.
    RAND=$(awk 'BEGIN { srand(); print int(rand() * 32768) }' /dev/null)
    if [ "$(date +%u)" -lt 6 ]; then
        [ "$RAND" -lt 16384 ] && break # 50% chance on weekdays.
    else
        [ "$RAND" -lt  8192 ] && break # 25% chance on weekends.
    fi

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

# Clone this repository.
git clone --depth 1 "git@github.com:$GIT_REPO.git"
cd commitr || exit 1

# Commit a file.
git commit --allow-empty -m "Update at: $(date '+%F %H:%M:%S %Z')."
git push

# Done; wait forever to prevent Kubernetes deployment from restarting the pod.
sleep infinity
