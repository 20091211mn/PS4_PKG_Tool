import os
import struct
import hashlib
import subprocess

def merge_pkg_bash(input_pattern, output_pkg):
    """دمج الأجزاء باستخدام أمر cat المباشر"""
    try:
        cmd = f"cat {input_pattern} > '{output_pkg}'"
        subprocess.run(cmd, shell=True, check=True)
        return True
    except Exception as e:
        print(f"Merge Error: {e}")
        return False

def split_pkg_bash(input_pkg, part_size_mb, output_prefix):
    """تقسيم الملف باستخدام أمر split المباشر"""
    try:
        cmd = f"split -b {part_size_mb}M '{input_pkg}' '{output_prefix}.part_'"
        subprocess.run(cmd, shell=True, check=True)
        return True
    except Exception as e:
        print(f"Split Error: {e}")
        return False

def get_pkg_info(pkg_path):
    """قراءة بيانات الهيدر واستخراج Title ID"""
    if not os.path.exists(pkg_path):
        return {"error": "File not found"}
    try:
        with open(pkg_path, 'rb') as f:
            if f.read(4) != b'\x7fCNT':
                return {"error": "Invalid PKG file"}
            f.seek(0x010)
            file_count = struct.unpack('>I', f.read(4))[0]
            f.seek(0x018)
            table_offset = struct.unpack('>I', f.read(4))[0]
            
            title_id = "Unknown"
            f.seek(table_offset)
            for _ in range(file_count):
                entry_id = struct.unpack('>I', f.read(4))[0]
                entry_offset = struct.unpack('>I', f.read(4))[0]
                entry_size = struct.unpack('>I', f.read(4))[0]
                f.read(4)
                if entry_id == 0x1000:
                    f.seek(entry_offset)
                    param_data = f.read(entry_size)
                    title_id = param_data.decode('utf-8', errors='ignore').strip('\x00')
                    break
            return {
                "file_name": os.path.basename(pkg_path),
                "file_size_gb": round(os.path.getsize(pkg_path) / (1024**3), 2),
                "title_id": title_id if title_id else "CUSAXXXXX"
            }
    except Exception as e:
        return {"error": str(e)}

def calculate_md5(file_path, chunk_size=8192):
    """حساب MD5 للتحقق من سلامة الملف"""
    md5_hash = hashlib.md5()
    try:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(chunk_size), b""):
                md5_hash.update(chunk)
        return md5_hash.hexdigest()
    except Exception:
        return None
