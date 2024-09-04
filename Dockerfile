# Use the Debian base image
FROM debian:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    make \
    gcc \
    clang \
    wget \
    fdisk \
    gcc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone the shimboot repository
RUN git clone https://github.com/ading2210/shimboot.git /opt/shimboot

# Set working directory
WORKDIR /opt/shimboot

# Create the start.sh script within the Dockerfile
RUN echo '#!/bin/bash\n' \
    'echo "Select a build option:"\n' \
    'echo "1) Build for UEFI"\n' \
    'echo "2) Build for Legacy BIOS"\n' \
    'echo "3) Build for both UEFI and Legacy BIOS"\n' \
    'read -p "Enter your choice (1/2/3): " choice\n' \
    'case $choice in\n' \
    '    1)\n' \
    '        echo "Building for dedede-lxde..."\n' \
    '        sudo ./build_complete.sh dedede desktop=lxde\n' \
    '        ;;\n' \
    '    2)\n' \
    '        echo "Building for jacuzzi-lxde..."\n' \
    '        sudo ./build_complete.sh jacuzzi desktop=lxde\n' \
    '        ;;\n' \
    '    3)\n' \
    '        echo "Building for corsola-lxde..."\n' \
    '        sudo ./build_complete.sh corsola desktop=lxde\n' \
    '        ;;\n' \
    '    *)\n' \
    '        echo "Invalid option selected!"\n' \
    '        exit 1\n' \
    '        ;;\n' \
    'esac\n' > start.sh

# Make the start.sh script executable
RUN chmod +x start.sh

# Entrypoint to start the script with options
ENTRYPOINT ["./start.sh"]
