# Use the Debian base image
FROM debian:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV BUILD_OPTION=3  # Default to building for both UEFI and Legacy BIOS

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    gcc \
    g++ \
    make \
    clang \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libssl-dev \
    efivar-dev \
    dosfstools \
    uuid-dev \
    wget \
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
    grub-efi-amd64-bin \
    grub-efi-ia32-bin \
    nodejs \
    npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install http-server globally using npm
RUN npm install -g http-server

# Clone the shimboot repository
RUN git clone https://github.com/ading2210/shimboot.git /opt/shimboot

# Set working directory
WORKDIR /opt/shimboot
# Create the start.sh script within the Dockerfile
RUN echo '#!/bin/bash\n' \
    'case $BUILD_OPTION in\n' \
    '    1)\n' \
    '        echo "Building for dedede..."\n' \
    '        ./build_complete.sh dedede desktop=lxde\n' \
    '        ;;\n' \
    '    2)\n' \
    '        echo "Building for jacuzzi..."\n' \
    '        ./build_complete.sh jacuzzi desktop=lxde\n' \
    '        ;;\n' \
    '    3)\n' \
    '        echo "Building for corsola..."\n' \
    '        ./build_complete.sh corsola desktop=lxde\n' \
    '        ;;\n' \
    '    *)\n' \
    '        echo "Invalid BUILD_OPTION selected! Defaulting to both UEFI and Legacy BIOS."\n' \
    '        make all\n' \
    '        ;;\n' \
    'esac\n' > start.sh

# Make the start.sh script executable
RUN chmod +x start.sh

# Create a simple HTML interface
RUN echo '<!DOCTYPE html>\n' \
    '<html lang="en">\n' \
    '<head>\n' \
    '    <meta charset="UTF-8">\n' \
    '    <meta name="viewport" content="width=device-width, initial-scale=1.0">\n' \
    '    <title>Build Interface</title>\n' \
    '</head>\n' \
    '<body>\n' \
    '    <h1>Build Interface</h1>\n' \
    '    <form action="/start" method="post">\n' \
    '        <button type="submit">Start Build</button>\n' \
    '    </form>\n' \
    '</body>\n' \
    '</html>\n' > /opt/shimboot/index.html

# Create a simple Node.js server script
RUN echo 'const http = require("http");\n' \
    'const fs = require("fs");\n' \
    'const exec = require("child_process").exec;\n' \
    'const server = http.createServer((req, res) => {\n' \
    '    if (req.method === "POST" && req.url === "/start") {\n' \
    '        exec("./start.sh", (error, stdout, stderr) => {\n' \
    '            if (error) {\n' \
    '                res.writeHead(500);\n' \
    '                res.end("Error: " + stderr);\n' \
    '                return;\n' \
    '            }\n' \
    '            res.writeHead(200);\n' \
    '            res.end("Build started: " + stdout);\n' \
    '        });\n' \
    '    } else {\n' \
    '        fs.readFile("index.html", (err, data) => {\n' \
    '            if (err) {\n' \
    '                res.writeHead(500);\n' \
    '                res.end("Error loading index.html");\n' \
    '                return;\n' \
    '            }\n' \
    '            res.writeHead(200, { "Content-Type": "text/html" });\n' \
    '            res.end(data);\n' \
    '        });\n' \
    '    }\n' \
    '});\n' \
    'server.listen(8080);\n' > /opt/shimboot/server.js

# Expose port 8080
EXPOSE 8080

# Command to start the server using Node.js
CMD ["node", "/opt/shimboot/server.js"]
