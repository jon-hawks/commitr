################################################################################
# Docker setup script.                                                         #
################################################################################
# Set OS.
FROM alpine:latest

# Build application.
WORKDIR /app
COPY commit.sh .

# Run application.
ENV GITHUB_TOKEN=$GITHUB_TOKEN
ENV GITHUB_REPO=$GITHUB_REPO
ENTRYPOINT ["sh", "/app/commit.sh"]
