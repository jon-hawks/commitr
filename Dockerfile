################################################################################
# Docker setup script.                                                         #
################################################################################
# Set OS.
FROM alpine:latest

# Run application.
RUN ls -l
COPY . /app
WORKDIR /app
RUN ls -l
RUN sh commit.sh
