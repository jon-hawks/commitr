# commitr
A boilerplate of infrastructure that deploys itself upon commit.

## Build Status
[![Main](https://github.com/jon-hawks/commitr/workflows/default/badge.svg?branch=main)](https://github.com/jon-hawks/commitr/actions)

## Operations
[Cleanup history and deployment-pipeline follow-up](operations.md).

## Deployment cycle

The single GKE pod waits 5 minutes to 24 hours before each commit opportunity.
It commits with a 50% chance on weekdays and 25% on weekends (UTC). A push to
`main` validates the scripts, builds and publishes the image, then replaces the
pod. The new pod starts its own timer.

Failed Git operations retry after 5 minutes. After a successful push, the old
pod waits an hour for replacement; if the pipeline failed, it resumes its
normal schedule instead of sleeping forever. `COMMIT_DELAY_MIN`,
`COMMIT_DELAY_MAX`, `RETRY_DELAY`, and `REDEPLOY_WAIT` override those delays in
seconds. Production uses the defaults.

GitHub's `production` environment needs `GIT_KEY` (raw, unencrypted SSH private
key with write access to this repository), `GIT_USER`, and `GIT_EMAIL` secrets.
The workflow passes them through the `commitr-git` Kubernetes Secret. The key
must authenticate as a repository writer: a push using the workflow's built-in
`GITHUB_TOKEN` would not trigger the next push workflow.

Cloud identifiers default to the current deployment in the workflow; existing
`GCP_ID`, `GAR_LOCATION`, `GAR_REPOSITORY`, `GAR_IMAGE`, `GKE_CLUSTER`, and
`GKE_ZONE` secrets can override them. Google authentication uses repository-
restricted Workload Identity Federation. No Google service-account key is used.

Use **Actions → default → Run workflow** on `main` to recover manually. A rollout
replaces the only committer, retaining two previous ReplicaSets. SSH host keys
are pinned in `github_known_hosts` from GitHub's published
[metadata](https://api.github.com/meta); update them if GitHub rotates its keys.

## Validation

Run `shellcheck commit.sh deploy.sh`, `shfmt -d -i 4 -ci commit.sh deploy.sh`,
`actionlint`, and `python3 -m unittest discover -s tests -v`.
Tests use a temporary local Git remote and never push to GitHub or change GKE.

[GitHub documents the workflow-token trigger restriction](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).
