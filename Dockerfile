# Use the Debian Bullseye base image for building
FROM debian:bullseye AS builder

# Set timezone and non-interactive mode
ENV TZ=UTC
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary tools and dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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
# Path to the built shimboot image (adjust this according to your setup)\n\
SHIMBOOT_IMAGE="/shimboot/data/shimboot_octopus.bin"\n\
\n\
# Create necessary directories for chroot\n\
mkdir -p ${CHROOT_MOUNT_DIR}/proc \\\n\
         ${CHROOT_MOUNT_DIR}/sys \\\n\
         ${CHROOT_MOUNT_DIR}/dev \\\n\
         ${CHROOT_MOUNT_DIR}/tmp\n\
\n\
# Check if the shimboot image exists\n\
if [[ ! -f "$SHIMBOOT_IMAGE" ]]; then\n\
    echo "Shimboot image not found at: $SHIMBOOT_IMAGE"\n\
    exit 1\n\
fi\n\
\n\
# Create loop devices if they do not exist\n\
for ((i=0; i<16; i++)); do\n\
    if [[ ! -e ${LOOP_DEVICE_PREFIX}$i ]]; then\n\
        mknod ${LOOP_DEVICE_PREFIX}$i b 7 $i\n\
    fi\n\
done\n\
\n\
# Set up the loop device for the shimboot image\n\
LOOP_DEVICE=$(losetup -f) || { echo "No available loop device"; exit 1; }\n\
losetup "$LOOP_DEVICE" "$SHIMBOOT_IMAGE" || { echo "Failed to associate $SHIMBOOT_IMAGE with $LOOP_DEVICE"; exit 1; }\n\
echo "Loop device $LOOP_DEVICE created for $SHIMBOOT_IMAGE"\n\
\n\
# Check for partitions and mount them\n\
for ((part=1; part<=4; part++)); do\n\
    if [[ -b ${LOOP_DEVICE}p$part ]]; then\n\
        mount ${LOOP_DEVICE}p$part "${CHROOT_MOUNT_DIR}/mnt_part$part" || { echo "Failed to mount ${LOOP_DEVICE}p$part"; exit 1; }\n\
        echo "Mounted ${LOOP_DEVICE}p$part to ${CHROOT_MOUNT_DIR}/mnt_part$part"\n\
    else\n\
        echo "Partition ${LOOP_DEVICE}p$part does not exist."\n\
    fi\n\
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
# Start the HTTP server in the background\n\
http-server -p 8080 -c-1 /shimboot/data &\n\
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
# Wait indefinitely to keep the container alive\n\
wait\n\
' > /shimboot/start.sh

# Make start.sh executable
RUN chmod +x /shimboot/start.sh

# Expose the default port for http-server
EXPOSE 8080

##### Final stage to create a clean minimal image #####
FROM debian:bullseye AS final

# Create the vscode user
RUN useradd -m vscode -s /bin/bash

# Allow vscode user to run sudo without a password
RUN apt-get update && apt-get install -y --no-install-recommends sudo && \
    echo "vscode ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set timezone and install required packages including Node.js
ENV TZ=UTC
RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    curl \
    wget \
    gnupg \
    nodejs \
    npm && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy shimboot directory and scripts from builder
COPY --from=builder /shimboot /shimboot

# Set the working directory
WORKDIR /shimboot

# Ensure http-server is installed globally
RUN npm install -g http-server

# Switch to the vscode user
USER vscode

# Use ENTRYPOINT to ensure scripts run in a fresh shell with proper signals propagated
ENTRYPOINT ["/bin/bash", "/shimboot/start.sh"]

# Add user-specific settings (adjust if necessary)
ENV NPM_CONFIG_LOGLEVEL warn
