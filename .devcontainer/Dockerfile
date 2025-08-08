FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Set environment variables for non-interactive installations
ENV DEBIAN_FRONTEND noninteractive

# Define arguments for username, UID, and GID (optional, but good practice)
ARG USERNAME=vscode

# Install the xz-utils package
RUN apt-get update \
    && apt-get install -y iptables python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN usermod -a -G sudo vscode

# Grant sudo privileges to the user without requiring a password
RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME