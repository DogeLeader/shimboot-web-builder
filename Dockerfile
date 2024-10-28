# Use the Debian Bullseye base image
FROM debian:bullseye AS builder

# Set timezone and non-interactive mode
ENV TZ=UTC
RUN apt-get update && apt-get install -y tzdata \
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
    unzip \
    zip \
    debootstrap \
    cpio \
    binwalk \
    pcregrep \
    cgpt \
    kmod \
    npm \
    lz4 \
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a directory for shimboot with full write permissions
RUN mkdir -p /shimboot && chmod 777 /shimboot

# Set the working directory
WORKDIR /shimboot

# Clone the shimboot repository
RUN git clone --depth=1 https://github.com/ading2210/shimboot.git . || { echo "Git clone failed"; exit 1; }

# Install http-server globally via npm
RUN npm install -g http-server || { echo "npm install failed"; exit 1; }

# Add mount_chroot.sh script directly into the Dockerfile
RUN echo '#!/bin/bash\n\
\n\
# Create necessary directories for chroot\n\
mkdir -p /shimboot/data/rootfs_octopus/proc \\\n\
         /shimboot/data/rootfs_octopus/sys \\\n\
         /shimboot/data/rootfs_octopus/dev\n\
\n\
# Create loop devices\n\
for i in {0..15}; do\n\
    if [[ ! -e /dev/loop$i ]]; then\n\
        mknod /dev/loop$i b 7 $i\n\
    fi\n\
done\n\
\n\
# Mount required filesystems with error handling\n\
mount -t proc /proc /shimboot/data/rootfs_octopus/proc || { echo "Failed to mount /proc"; exit 1; }\n\
mount -t sysfs /sys /shimboot/data/rootfs_octopus/sys || { echo "Failed to mount /sys"; exit 1; }\n\
mount --bind /dev /shimboot/data/rootfs_octopus/dev || { echo "Failed to mount /dev"; exit 1; }' > /shimboot/mount_chroot.sh

# Make mount_chroot.sh executable
RUN chmod +x /shimboot/mount_chroot.sh

# Add start.sh script directly into the Dockerfile
RUN echo '#!/bin/bash\n\
\n\
# Start the HTTP server in the background\n\
http-server -p 8080 -c-1 &\n\
\n\
# Wait for the server to start\n\
sleep 5\n\
\n\
# Execute the build script and mount chroot\n\
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
wait' > /shimboot/start.sh

# Make start.sh executable
RUN chmod +x /shimboot/start.sh

# Expose the default port for http-server
EXPOSE 8080

# Final stage to create a clean minimal image
FROM debian:bullseye

# Set timezone
ENV TZ=UTC
RUN apt-get update && apt-get install -y tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy shimboot directory and scripts from builder
COPY --from=builder /shimboot /shimboot

# Set the working directory
WORKDIR /shimboot

# Use ENTRYPOINT to ensure scripts run in a fresh shell with proper signals propagated
ENTRYPOINT ["/bin/bash", "/shimboot/start.sh"]
