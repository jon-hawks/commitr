################################################################################
# Docker setup script.                                                         #
################################################################################
# Set OS.
FROM alpine

# Build application.
COPY commit.sh /commit.sh

# Run application.
ENTRYPOINT ["sh", "/commit.sh"]
