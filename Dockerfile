# Base image
FROM debian:latest

# Install necessary dependencies for shimboot and Node.js
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
    nodejs \
    npm \
    && apt-get clean

# Create a working directory for shimboot
WORKDIR /tmp/shimboot

# Clone shimboot repository
RUN git clone https://github.com/ading2210/shimboot.git .

# Install Node.js dependencies for the server
WORKDIR /usr/src/app
RUN npm init -y
RUN npm install express

# Create the Express server that builds and serves shimboot images
RUN echo "const express = require('express');\n\
const { exec } = require('child_process');\n\
const path = require('path');\n\
const fs = require('fs');\n\
const app = express();\n\
const port = process.env.PORT || 5000;\n\
\n\
// Route to trigger the shimboot build process\n\
app.get('/build', (req, res) => {\n\
    const buildCommand = './build_complete.sh jacuzzi desktop=lxqt';\n\
    exec(buildCommand, { cwd: '/tmp/shimboot' }, (err, stdout, stderr) => {\n\
        if (err) {\n\
            console.error(\`Error during build: \${stderr}\`);\n\
            return res.status(500).send('Build failed');\n\
        }\n\
        console.log(stdout);\n\
        const builtImagePath = '/tmp/shimboot/output/built-image.img';\n\
        if (fs.existsSync(builtImagePath)) {\n\
            res.download(builtImagePath, 'shimboot-built-image.img');\n\
        } else {\n\
            res.status(404).send('Built image not found');\n\
        }\n\
    });\n\
});\n\
\n\
// Start the server\n\
app.listen(port, () => {\n\
    console.log(\`Server is running on port \${port}\`);\n\
});" > server.js

# Expose the port for Render (Render dynamically sets ports, so use the environment variable)
EXPOSE 10000

# Start the Express server when the container runs
CMD ["node", "server.js"]
