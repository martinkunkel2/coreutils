FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# install gnu coreutils test dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       attr \
       autoconf \
       autopoint \
       bison \
       g++ \
       gcc \
       gdb \
       gperf \
       libacl1-dev \
       libattr1-dev \
       libcap-dev \
       libexpect-perl \
       libselinux1-dev \
       libsystemd-dev \
       python3-pyinotify \
       quilt \
       texinfo \
       valgrind \
    && rm -rf /var/lib/apt/lists/*

# automake 1.18 is required, but 1.16 is the default in Ubuntu 24.04, so we need to install it from source
RUN wget https://ftp.gnu.org/pub/gnu/automake/automake-1.18.1.tar.gz \
    && tar -xzf automake-1.18.1.tar.gz \
    && cd automake-1.18.1 \
    && ./configure --prefix=/usr/local \
    && make install \
    && cd .. \
    && rm -rf automake-1.18.1 automake-1.18.1.tar.gz

# install dependencies for uutils
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        clang \
        gdb \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

# pre-commit
RUN pip3 install --break-system-packages pre-commit
