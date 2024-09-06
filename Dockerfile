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

# Install Flask for the web interface
RUN pip3 install Flask

# Clone the shimboot repository
RUN git clone https://github.com/ading2210/shimboot.git /opt/shimboot

# Create a build directory in /tmp
RUN mkdir -p /tmp/shimboot-build

# Set the working directory to /tmp to avoid permission issues
WORKDIR /tmp/shimboot-build

# Expose port 8080 for Render
EXPOSE 8080

# Add the Flask app script directly in the Dockerfile
RUN echo 'from flask import Flask, request, send_from_directory, jsonify\n\
import subprocess\n\
import os\n\
\n\
app = Flask(__name__)\n\
\n\
# Define the directory for building the shimboot images\n\
BUILD_DIR = \"/tmp/shimboot-build\"\n\
\n\
@app.route("/")\n\
def index():\n\
    return """\n\
    <h2>Shimboot Build Interface</h2>\n\
    <form action=\"/build\" method=\"post\">\n\
        <button type=\"submit\">Build Shimboot Images</button>\n\
    </form>\n\
    """\n\
\n\
@app.route("/build", methods=["POST"])\n\
def build_shimboot():\n\
    try:\n\
        # Run the build process with the custom build command in the temporary build directory\n\
        subprocess.run([\"./build_complete.sh\", \"jacuzzi\", \"desktop=lxqt\"], cwd=BUILD_DIR, check=True)\n\
\n\
        # List the built files for download\n\
        files = os.listdir(BUILD_DIR)\n\
        file_links = "".join(f\'<li><a href=\"/download/{{file}}\">{{file}}</a></li>\' for file in files)\n\
\n\
        return f"""\n\
        <h2>Build Complete!</h2>\n\
        <ul>{{file_links}}</ul>\n\
        """\n\
\n\
    except subprocess.CalledProcessError as e:\n\
        return f\"<h2>Error occurred during build process: {str(e)}</h2>\"\n\
\n\
@app.route("/download/<filename>")\n\
def download_file(filename):\n\
    return send_from_directory(BUILD_DIR, filename)\n\
\n\
if __name__ == "__main__":\n\
    # Ensure the build directory exists\n\
    if not os.path.exists(BUILD_DIR):\n\
        os.makedirs(BUILD_DIR)\n\
\n\
    app.run(host="0.0.0.0", port=8080)\n' > /opt/shimboot/app.py

# Start the Flask web server on port 8080
CMD ["python3", "/opt/shimboot/app.py"]
