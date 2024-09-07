# Base image
FROM debian:latest

# Install necessary packages
RUN apt-get update && apt-get install -y \
    git \
    npm \
    nodejs \
    build-essential \
    cmake \
    clang \
    gcc \
    g++ \
    zlib1g-dev \
    libuv1-dev \
    libjson-c-dev \
    libwebsockets-dev \
    sudo \
    curl \
    wget \
    net-tools \
    vim \
    openssh-client \
    locales \
    bash-completion \
    iputils-ping \
    htop \
    gnupg2 \
    tmux \
    screen \
    zsh \
    qemu-user-static \
    fdisk \
    binfmt-support \
    && apt-get clean

# Symlink nodejs to node (in case the system installs as nodejs)
RUN ln -s /usr/bin/nodejs /usr/bin/node || true

# Set environment variable for terminal type
ENV TERM=xterm-256color

# Download and install ttyd from a specific version for compatibility
RUN git clone --branch 1.6.3 https://github.com/tsl0922/ttyd.git /ttyd-src && \
    cd /ttyd-src && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make && \
    make install

# Clone the shimboot repository into /tmp
RUN git clone https://github.com/ading2210/shimboot.git /tmp/shimboot

# Set working directory to /tmp/shimboot
WORKDIR /tmp/shimboot

# Build shimboot
RUN chmod +x ./build_complete.sh && ./build_complete.sh jacuzzi desktop=lxqt

# Expose the port for ttyd
EXPOSE 10000

# Run ttyd with shimboot command in the bash session
CMD ["ttyd", "-p", "10000", "bash", "-c", "/tmp/shimboot/build_complete.sh jacuzzi desktop=lxqt && exec bash"]
