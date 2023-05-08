################################################################################
# Docker setup script.                                                         #
################################################################################
# Set OS.
FROM alpine:latest

# Build application.
COPY . /app
WORKDIR /app

# Run application.
ENTRYPOINT ["bash", "commit.sh"]
