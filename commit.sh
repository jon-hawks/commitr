#!/bin/sh
################################################################################
# Push periodic empty commits; a successful deployment replaces this process.   #
################################################################################
set -eu

# Validate configuration before starting the timer.
: "${GIT_EMAIL:?GIT_EMAIL is required}"
: "${GIT_USER:?GIT_USER is required}"
: "${GITHUB_REPO:?GITHUB_REPO is required}"
GIT_BRANCH=${GIT_BRANCH:-main}
GIT_KEY_FILE=${GIT_KEY_FILE:-/var/run/commitr-ssh/id}
GIT_KNOWN_HOSTS=${GIT_KNOWN_HOSTS:-/etc/ssh/ssh_known_hosts}
COMMIT_DELAY_MIN=${COMMIT_DELAY_MIN:-300}
COMMIT_DELAY_MAX=${COMMIT_DELAY_MAX:-86400}
RETRY_DELAY=${RETRY_DELAY:-300}
REDEPLOY_WAIT=${REDEPLOY_WAIT:-3600}
for delay in "$COMMIT_DELAY_MIN" "$COMMIT_DELAY_MAX" "$RETRY_DELAY" "$REDEPLOY_WAIT"; do
    case "$delay" in
        '' | *[!0-9]* | 0*)
            echo "Delays must be positive integers without leading zeros." >&2
            exit 1
            ;;
    esac
done
[ "$COMMIT_DELAY_MIN" -le "$COMMIT_DELAY_MAX" ] || exit 1
[ -s "$GIT_KNOWN_HOSTS" ] || exit 1
ssh-keygen -y -P '' -f "$GIT_KEY_FILE" >/dev/null

# Isolate Git state and pin SSH to the supplied key and published host keys.
umask 077
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
trap 'exit 0' INT TERM
cp "$GIT_KEY_FILE" "$workdir/key"
cp "$GIT_KNOWN_HOSTS" "$workdir/known_hosts"
export GIT_SSH_COMMAND="ssh -F /dev/null -i $workdir/key -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$workdir/known_hosts -o ConnectTimeout=30 -o ServerAliveInterval=15 -o ServerAliveCountMax=3"
export GIT_TERMINAL_PROMPT=0

# Background waits let PID 1 handle Kubernetes termination promptly.
pause() {
    sleep "$1" &
    wait "$!"
}

# Clone afresh on retries, including when another writer won a push race.
publish_commit() (
    rm -rf "$workdir/repository"
    git clone --depth 1 --no-tags --single-branch --branch "$GIT_BRANCH" \
        "ssh://git@github.com/$GITHUB_REPO.git" "$workdir/repository" || exit 1
    cd "$workdir/repository" || exit 1
    git -c user.email="$GIT_EMAIL" -c user.name="$GIT_USER" commit --allow-empty \
        -m "Update at: $(date -u '+%F %H:%M:%S UTC')." || exit 1
    git push origin "HEAD:refs/heads/$GIT_BRANCH"
)

# Preserve weekday/weekend probabilities without logging every second.
while true; do
    delay=$(shuf -i "$COMMIT_DELAY_MIN-$COMMIT_DELAY_MAX" -n 1)
    echo "Next commit opportunity in $delay seconds."
    pause "$delay"
    probability=50
    if [ "$(date -u +%u)" -ge 6 ]; then
        probability=25
    fi
    if [ "$(shuf -i 1-100 -n 1)" -gt "$probability" ]; then
        continue
    fi

    # Retry network/push failures; never mistake failure for completion.
    until publish_commit; do
        echo "Commit/push failed; retrying in $RETRY_DELAY seconds." >&2
        pause "$RETRY_DELAY"
    done

    # Normally replaced here; resume the schedule if the pipeline failed.
    echo "Commit pushed; allowing $REDEPLOY_WAIT seconds for redeployment."
    pause "$REDEPLOY_WAIT"
    echo "Still running; resuming the commit schedule."
done
