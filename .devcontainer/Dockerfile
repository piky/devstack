FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Set environment variables for non-interactive installations
ENV DEBIAN_FRONTEND noninteractive

# Install the xz-utils package
RUN apt-get update \
    && apt-get install -y iptables python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN usermod -a -G sudo vscode