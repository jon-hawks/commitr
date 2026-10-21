################################################################################
# Docker setup script.                                                         #
################################################################################
# Set OS.
FROM alpine:latest

# Build application.
WORKDIR /app
COPY commit.sh .

# Run application.
ENTRYPOINT ["sh", "/app/commit.sh"]
