# Use debian:latest as the base image
FROM debian:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    zip \
    debootstrap \
    cpio \
    binwalk \
    pcregrep \
    cgpt \
    kmod \
    pv \
    lz4 \
    tar \
    make \
    gcc \
    cmake \
    libjson-c-dev \
    libwebsockets-dev \
    build-essential \
    qemu-user-static \
    fdisk \
    binfmt-support

# Clone the shimboot repository into /tmp (or any unrestricted directory)
RUN git clone https://github.com/ading2210/shimboot.git /tmp/shimboot

# Set working directory to /tmp/shimboot
WORKDIR /tmp/shimboot

# Build the shimboot project during the build process
RUN chmod +x ./build_complete.sh

# Clone the ttyd repository
WORKDIR /opt
RUN git clone https://github.com/tsl0922/ttyd.git

# Build ttyd from source
WORKDIR /opt/ttyd
RUN mkdir build && cd build && cmake .. && make && make install

# Expose port 10000 for ttyd
EXPOSE 10000

# Always run as root
USER root

# Run shimboot and ttyd concurrently
CMD ["bash", "-c", "./tmp/shimboot/build_complete.sh jacuzzi desktop=lxqt && ttyd -p 10000 bash"]
