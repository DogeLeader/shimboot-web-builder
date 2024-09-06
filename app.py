from flask import Flask, request, send_from_directory, jsonify
import subprocess
import os

app = Flask(__name__)

# Define the directory for building the shimboot images
BUILD_DIR = "/tmp/shimboot-build"

@app.route("/")
def index():
    return """
    <h2>Shimboot Build Interface</h2>
    <form action="/build" method="post">
        <button type="submit">Build Shimboot Images</button>
    </form>
    """

@app.route("/build", methods=["POST"])
def build_shimboot():
    try:
        # Run the build process with the custom build command in the temporary build directory
        subprocess.run(["./build_complete.sh", "jacuzzi", "desktop=lxqt"], cwd=BUILD_DIR, check=True)

        # List the built files for download
        files = os.listdir(BUILD_DIR)
        file_links = "".join(f'<li><a href="/download/{file}">{file}</a></li>' for file in files)

        return f"""
        <h2>Build Complete!</h2>
        <ul>{file_links}</ul>
        """
    except subprocess.CalledProcessError as e:
        return f"<h2>Error occurred during build process: {str(e)}</h2>"

@app.route("/download/<filename>")
def download_file(filename):
    return send_from_directory(BUILD_DIR, filename)

if __name__ == "__main__":
    # Ensure the build directory exists
    if not os.path.exists(BUILD_DIR):
        os.makedirs(BUILD_DIR)

    # Run the Flask app on port 8080
    app.run(host="0.0.0.0", port=8080)
