import os
import subprocess
import hashlib

def get_pkg_info(file_path):
    """قراءة هيدر ملف PKG واستخراج CUSA وسعة الملف الحقيقية"""
    if not os.path.exists(file_path):
        return {"error": "File not found"}
    
    file_size = os.path.getsize(file_path)
    file_size_gb = file_size / (1024 * 1024 * 1024)
    
    cusa_id = "غير معروف"
    try:
        with open(file_path, "rb") as f:
            header = f.read(0x300)
            for i in range(len(header) - 9):
                chunk = header[i:i+9]
                if chunk.startswith(b"CUSA") and chunk[4:9].isdigit():
                    cusa_id = chunk.decode('utf-8', errors='ignore')
                    break
    except Exception as e:
        print(f"Header read error: {e}")

    return {
        "path": file_path,
        "size_bytes": file_size,
        "size_str": f"{file_size_gb:.2f} GB" if file_size_gb >= 1 else f"{file_size / (1024*1024):.2f} MB",
        "cusa": cusa_id
    }

def calculate_md5(file_path):
    """حساب مصفوفة التجزئة MD5 للتحقق من سلامة الملفات"""
    hash_md5 = hashlib.md5()
    try:
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096 * 1024), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    except Exception:
        return None

def split_pkg_bash(file_path, output_dir=None, chunk_size="4G"):
    """تقسيم الملف باستخدام أدوات النظام السريعة"""
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
    """دمج أجزاء ملف الـ PKG عبر النظام"""
    cmd = f"cat {pattern} > '{output_path}'"
    try:
        result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.returncode == 0
    except Exception as e:
        print(f"Error merging: {e}")
        return False
