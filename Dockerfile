# Use the Debian Bullseye base image for building
FROM debian:bullseye AS builder

# Set timezone and non-interactive mode
ENV TZ=UTC
RUN apt-get update && apt-get install -y --no-install-recommends tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    clang \
    gcc \
    g++ \
    qemu-user-static \
    binfmt-support \
    curl \
    wget \
    npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a directory for shimboot with full write permissions
RUN mkdir -p /shimboot && chmod 777 /shimboot

# Clone the shimboot repository
RUN git clone --depth=1 https://github.com/ading2210/shimboot.git /shimboot || { echo "Git clone failed"; exit 1; }

# Install http-server globally via npm
RUN npm install -g http-server || { echo "npm install failed"; exit 1; }

# Create mount_chroot.sh script
RUN echo '#!/bin/bash\n\
\n\
set -e\n\
set -x\n\
\n\
# Base path for loop devices\n\
LOOP_DEVICE_PREFIX="/dev/loop"\n\
# Base mount point for chroot\n\
CHROOT_MOUNT_DIR="/shimboot/data/rootfs_octopus"\n\
\n\
# Create necessary directories for chroot\n\
mkdir -p ${CHROOT_MOUNT_DIR}/proc \\\n\
         ${CHROOT_MOUNT_DIR}/sys \\\n\
         ${CHROOT_MOUNT_DIR}/dev \\\n\
         ${CHROOT_MOUNT_DIR}/tmp\n\
\n\
# Create loop devices if they do not exist\n\
for ((i=0; i<16; i++)); do\n\
    if [[ ! -e ${LOOP_DEVICE_PREFIX}$i ]]; then\n\
        mknod ${LOOP_DEVICE_PREFIX}$i b 7 $i\n\
    fi\n\
done\n\
\n\
# Check and set up loop devices\n\
for img in /path/to/your/image*.img; do\n\
    LOOP_DEVICE=$(losetup -f) || { echo "No available loop device"; exit 1; }\n\
    losetup "$LOOP_DEVICE" "$img" || { echo "Failed to associate $img with $LOOP_DEVICE"; exit 1; }\n\
\n\
    # Mount required sub-partitions of the loop device\n\
    for ((part=1; part<=4; part++)); do\n\
        if [[ -e ${LOOP_DEVICE}p$part ]]; then\n\
            mount ${LOOP_DEVICE}p$part "${CHROOT_MOUNT_DIR}/mnt_part$part" || { echo "Failed to mount ${LOOP_DEVICE}p$part"; exit 1; }\n\
        fi\n\
    done\n\
done\n\
\n\
# Mount the necessary directories\n\
mount --bind /shimboot/data ${CHROOT_MOUNT_DIR}/data || { echo "Failed to mount /shimboot/data"; exit 1; }\n\
\n\
# Mount required filesystems with error handling\n\
mount -t proc /proc ${CHROOT_MOUNT_DIR}/proc || { echo "Failed to mount /proc"; exit 1; }\n\
mount -t sysfs /sys ${CHROOT_MOUNT_DIR}/sys || { echo "Failed to mount /sys"; exit 1; }\n\
mount --bind /dev ${CHROOT_MOUNT_DIR}/dev || { echo "Failed to mount /dev"; exit 1; }\n\
\n\
# Optional: Display mounted devices for debugging\n\
echo "Mounting complete. Current mounts:"\n\
mount\n\
' > /shimboot/mount_chroot.sh

# Make mount_chroot.sh executable
RUN chmod +x /shimboot/mount_chroot.sh

# Create start.sh script
RUN echo '#!/bin/bash\n\
\n\
# Function to check available loop devices\n\
check_loop_devices() {\n\
    for ((i=0; i<16; i++)); do\n\
        if [[ -e /dev/loop$i ]]; then\n\
            echo "Loop device /dev/loop$i is available."\n\
        else\n\
            echo "Loop device /dev/loop$i is not available."\n\
        fi\n\
    done\n\
\n\
    # Check if losetup can find an available loop device\n\
    LOOP_DEVICE=$(losetup -f)\n\
    if [[ ! -z $LOOP_DEVICE ]]; then\n\
        echo "An available loop device is: $LOOP_DEVICE"\n\
        return 0\n\
    else\n\
        echo "No available loop devices."\n\
        return 1\n\
    fi\n\
}\n\
\n\
# Check loop devices\n\
if ! check_loop_devices; then\n\
    echo "Loop devices are not available. Exiting..."\n\
    exit 1\n\
fi\n\
\n\
# Start the HTTP server in the background\n\
http-server -p 8080 -c-1 &\n\
\n\
# Wait for the server to start\n\
sleep 5\n\
\n\
# Execute the build script\n\
if ! ./build_complete.sh octopus desktop=xfce; then\n\
    echo "Build script failed"\n\
    exit 1\n\
fi\n\
\n\
# Run mount_chroot.sh to set up the chroot environment\n\
if ! ./mount_chroot.sh; then\n\
    echo "Mount script failed"\n\
    exit 1\n\
fi\n\
\n\
# Wait indefinitely\n\
wait\n\
' > /shimboot/start.sh

# Make start.sh executable
RUN chmod +x /shimboot/start.sh

# Expose the default port for http-server
EXPOSE 8080

# Final stage to create a clean minimal image
FROM debian:bullseye

# Set timezone and install required packages including Node.js
ENV TZ=UTC
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    curl \
    wget \
    gnupg \
    nodejs \
    npm \
    cpio \
    unzip \
    zip \
    debootstrap \
    binwalk \
    pcregrep \
    lz4 \
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Some packages may need to be added from backports if they're not available in standard repos
RUN echo "deb http://deb.debian.org/debian bullseye-backports main" >> /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    cgpt \
    kmod \
    pv \
    npm \
    git \
    fdisk \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* 

# Copy shimboot directory and scripts from builder
COPY --from=builder /shimboot /shimboot

# Set the working directory
WORKDIR /shimboot

RUN npm i -g http-server

# Use ENTRYPOINT to ensure scripts run in a fresh shell with proper signals propagated
ENTRYPOINT ["/bin/bash", "/shimboot/start.sh"]
