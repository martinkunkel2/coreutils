FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# install gnu coreutils test dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       attr \
       autoconf \
       automake \
       autopoint \
       bison \
       g++ \
       gcc \
       gdb \
       gperf \
       jq \
       libacl1-dev \
       libattr1-dev \
       libcap-dev \
       libexpect-perl \
       libselinux1-dev \
       python3-pyinotify \
       quilt \
       texinfo \
       valgrind \
    && rm -rf /var/lib/apt/lists/*

# install dependencies for uutils
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        clang \
        gdb \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# pre-commit
RUN pip3 install --break-system-packages pre-commit

# lima-vm: used to run virtual machines, e.g. for selinux tests
RUN LIMA_VERSION="2.0.1" && \
    curl -fsSL "https://github.com/lima-vm/lima/releases/download/v${LIMA_VERSION}/lima-${LIMA_VERSION}-$(uname -s)-$(uname -m).tar.gz" | tar Cxzvm /usr/local && \
    curl -fsSL "https://github.com/lima-vm/lima/releases/download/v${LIMA_VERSION}/lima-additional-guestagents-${LIMA_VERSION}-$(uname -s)-$(uname -m).tar.gz" | tar Cxzvm /usr/local
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        qemu-system \
        qemu-utils \
    && rm -rf /var/lib/apt/lists/*
