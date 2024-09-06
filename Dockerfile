# Use a Debian base image
FROM debian:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install required dependencies including qemu-user-static and binfmt-support
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    zip \
    debootstrap \
    cpio \
    binwalk \
    pcregrep \
    fdisk \
    cgpt \
    kmod \
    pv \
    lz4 \
    tar \
    qemu-user-static \
    binfmt-support \
    python3 \
    python3-pip \
    build-essential \
    && apt-get clean

# Remove the EXTERNALLY-MANAGED file to bypass the restriction
RUN rm -rf /usr/lib/python3.11/EXTERNALLY-MANAGED

# Install Flask for the web interface
RUN pip3 install Flask

# Clone the shimboot repository
RUN git clone https://github.com/ading2210/shimboot.git /opt/shimboot

# Create a build directory in /tmp
RUN mkdir -p /tmp/shimboot-build

# Set the working directory to /tmp to avoid permission issues
WORKDIR /tmp/shimboot-build

# Copy the build script and ensure it is executable
COPY build_complete.sh /tmp/shimboot-build/
RUN chmod +x /tmp/shimboot-build/build_complete.sh

# Copy the Flask app script
COPY app.py /opt/shimboot/app.py

# Expose port 8080 for Render
EXPOSE 8080

# Start the Flask web server on port 8080
CMD ["python3", "/opt/shimboot/app.py"]
