import os
import subprocess

def get_pkg_info(file_path):
    if not os.path.exists(file_path):
        return {"error": "File not found"}
    file_size = os.path.getsize(file_path)
    file_size_gb = file_size / (1024 * 1024 * 1024)
    return {
        "path": file_path,
        "size_bytes": file_size,
        "size_str": f"{file_size_gb:.2f} GB" if file_size_gb >= 1 else f"{file_size / (1024*1024):.2f} MB"
    }

def split_pkg_bash(file_path, output_dir=None, chunk_size="4G"):
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
    except Exception as e:
        print(f"Error splitting: {e}")
        return False

def merge_pkg_bash(pattern, output_path):
    cmd = f"cat {pattern} > '{output_path}'"
    try:
        result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.returncode == 0
    except Exception as e:
        print(f"Error merging: {e}")
        return False
