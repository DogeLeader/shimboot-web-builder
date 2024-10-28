# Use the Debian Bullseye base image
FROM debian:bullseye

# Set timezone (optional, you can specify any timezone if needed)
ENV TZ=UTC
RUN apt-get update && apt-get install -y tzdata

# Set the non-interactive mode for Debian
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    clang \
    gcc \
    g++ \
    qemu-user-static \
    binfmt-support \
    fdisk \
    sudo \
    curl \
    wget \
    unzip \
    zip \
    debootstrap \
    cpio \
    binwalk \
    pcregrep \
    cgpt \
    kmod \
    npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y

# Create a directory for shimboot with full write permissions
RUN mkdir -p /shimboot && chmod 777 /shimboot

# Set the working directory
WORKDIR /shimboot

# Clone the shimboot repository
RUN git clone https://github.com/ading2210/shimboot.git .

# Set up architecture for arm64 build
RUN echo "export ARCH=arm64" >> /etc/profile

# Install http-server globally via npm
RUN npm install -g http-server

# Expose the default port for http-server
EXPOSE 8080

# Command to build the shimboot and start http-server
CMD ["/bin/bash", "-c", "sudo ./build_complete.sh octopus desktop=xfce && http-server -p 8080 -c-1"]
