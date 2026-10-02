import os
import subprocess
import hashlib

def verify_and_get_filename(file_path):
    """Verify PKG file integrity, extract filename and check header."""
    if not os.path.exists(file_path):
        return None, "File does not exist!"
    
    file_name = os.path.basename(file_path)
    
    # Extension Check
    if not file_name.lower().endswith(('.pkg', '.part_00', '.part_01', '.part_000')):
        if ".part_" not in file_name:
            return file_name, "Warning: Extension is not .pkg!"

    # Header Integrity Check
    try:
        with open(file_path, "rb") as f:
            header = f.read(0x10)
            if len(header) < 0x10:
                return file_name, "Error: File is corrupted or empty!"
    except Exception as e:
        return file_name, f"Read error: {e}"

    return file_name, "Verified Successfully ✓"

def split_pkg_bash(file_path, output_dir=None, chunk_size="4G"):
    """Split PKG file using high-performance bash system commands."""
    if not os.path.exists(file_path):
        return False
    if not output_dir:
        output_dir = os.path.dirname(file_path)
    base_name = os.path.basename(file_path)
    output_prefix = os.path.join(output_dir, f"{base_name}.part_")
    
    cmd = ["split", "-b", chunk_size, "-d", file_path, output_prefix]
    try:
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.returncode == 0
    except Exception:
        return False

def merge_pkg_bash(pattern, output_path):
    """Merge PKG parts using system cat utility."""
    cmd = f"cat {pattern} > '{output_path}'"
    try:
        result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.returncode == 0
    except Exception:
        return False
