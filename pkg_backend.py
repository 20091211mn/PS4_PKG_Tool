import os
import glob

CHUNK = 4000 * 1024 * 1024  # اقل من حد FAT32
BUF = 8 * 1024 * 1024


def verify_and_get_filename(file_path):
    if not file_path or not os.path.exists(file_path):
        return None, "File does not exist!"

    file_name = os.path.basename(file_path)

    if not file_name.lower().endswith(".pkg") and ".part_" not in file_name:
        return file_name, "Warning: Extension is not .pkg!"

    try:
        with open(file_path, "rb") as f:
            header = f.read(0x10)
            if len(header) < 0x10:
                return file_name, "Error: File is corrupted or empty!"
    except Exception as e:
        return file_name, f"Read error: {e}"

    return file_name, "Verified Successfully"


def split_pkg(file_path, output_dir=None, chunk=CHUNK):
    try:
        output_dir = output_dir or os.path.dirname(file_path)
        prefix = os.path.join(output_dir, os.path.basename(file_path) + ".part_")
        idx = 0
        with open(file_path, "rb") as src:
            while True:
                written = 0
                out = None
                while written < chunk:
                    data = src.read(min(BUF, chunk - written))
                    if not data:
                        break
                    if out is None:
                        out = open(f"{prefix}{idx:02d}", "wb")
                    out.write(data)
                    written += len(data)
                if out is None:
                    break
                out.close()
                idx += 1
        return True, f"{idx} parts created"
    except Exception as e:
        return False, str(e)


def merge_pkg(base_prefix, output_path):
    try:
        parts = sorted(glob.glob(glob.escape(base_prefix) + ".part_*"))
        if not parts:
            return False, "No parts found"
        with open(output_path, "wb") as out:
            for p in parts:
                with open(p, "rb") as f:
                    while True:
                        data = f.read(BUF)
                        if not data:
                            break
                        out.write(data)
        return True, f"{len(parts)} parts merged"
    except Exception as e:
        return False, str(e)
