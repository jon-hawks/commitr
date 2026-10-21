################################################################################
# Build a ready-to-run committer; no package installation at container startup.  #
################################################################################
FROM alpine:3.24
RUN apk add --no-cache git openssh-client

# Include only runtime files; credentials arrive through a Kubernetes Secret.
WORKDIR /app
COPY commit.sh .
COPY github_known_hosts /etc/ssh/ssh_known_hosts
ENTRYPOINT ["sh", "/app/commit.sh"]
