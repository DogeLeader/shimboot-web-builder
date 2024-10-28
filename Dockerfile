# Use the Debian Bullseye base image
FROM debian:bullseye

# Set timezone (optional, you can specify any timezone if needed)
ENV TZ=UTC
RUN apt-get update && apt-get install -y tzdata

# Set the non-interactive mode for Debian
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages, including sudo, and other dependencies
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
    pv \
    lz4 \
    sudo \
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

# Create mount_chroot.sh script
RUN echo '#!/bin/bash\n\
# Create necessary directories for chroot\n\
mkdir -p /shimboot/data/rootfs_octopus/proc\n\
mkdir -p /shimboot/data/rootfs_octopus/sys\n\
mkdir -p /shimboot/data/rootfs_octopus/dev\n\
\n\
# Create loop devices\n\
for i in {0..15}; do \n\
    if [[ ! -e /dev/loop$i ]]; then \n\
        mknod /dev/loop$i b 7 $i; \n\
    fi;\n\
done;\n\
\n\
# Mount required filesystems\n\
mount -t proc /proc /shimboot/data/rootfs_octopus/proc\n\
mount -t sysfs /sys /shimboot/data/rootfs_octopus/sys\n\
mount --bind /dev /shimboot/data/rootfs_octopus/dev\n' \
> /shimboot/mount_chroot.sh && \
chmod +x /shimboot/mount_chroot.sh

# Create start.sh script
RUN echo '#!/bin/bash\n\
# Start http-server in the background\n\
http-server -p 8080 -c-1 &\n\
# Wait a little for the server to start (you can adjust this)\n\
sleep 5\n\
# Execute the build script and mount chroot\n\
./build_complete.sh octopus desktop=xfce\n\
./mount_chroot.sh\n\
# Wait for the server to finish before exiting\n\
wait' \
> /shimboot/start.sh && \
chmod +x /shimboot/start.sh

# Command to run the new start script
CMD ["/bin/bash", "/shimboot/start.sh"]
