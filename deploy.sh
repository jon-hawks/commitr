#!/bin/sh
################################################################################
# Safely pass credentials to Kubernetes and wait for the new image to roll out.  #
################################################################################
set -eu
: "${IMAGE_URI:?IMAGE_URI is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GIT_KEY:?GIT_KEY must contain an unencrypted SSH private key}"
: "${GIT_EMAIL:?GIT_EMAIL is required}"
: "${GIT_USER:?GIT_USER is required}"

# Files preserve multiline keys and keep secret values out of CLI arguments.
umask 077
credentials=$(mktemp -d)
trap 'rm -rf "$credentials"' EXIT
trap 'exit 1' INT TERM
printf '%s\n' "$GIT_KEY" >"$credentials/key"
printf '%s' "$GIT_EMAIL" >"$credentials/email"
printf '%s' "$GIT_USER" >"$credentials/user"
ssh-keygen -y -P '' -f "$credentials/key" >/dev/null
kubectl create secret generic commitr-git --namespace default \
    --from-file=key="$credentials/key" --from-file=email="$credentials/email" \
    --from-file=user="$credentials/user" --dry-run=client -o yaml >"$credentials/secret.yml"
kubectl apply --server-side --field-manager=commitr --force-conflicts -f "$credentials/secret.yml"

# Substitute only public configuration, never arbitrary secret text into YAML.
# shellcheck disable=SC2016 # envsubst needs literal variable names.
envsubst '${IMAGE_URI} ${GITHUB_REPOSITORY}' <.deployment.yml >"$credentials/deployment.yml"
kubectl apply -f "$credentials/deployment.yml"
kubectl rollout status deployment/default --namespace default --timeout=5m
