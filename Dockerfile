################################################################################
# Docker setup script.                                                         #
################################################################################
# Set OS.
FROM alpine:latest

# Build application.
COPY commit.sh /app/commit.sh
WORKDIR /app

# Run application.
ENTRYPOINT ["commit.sh"]
