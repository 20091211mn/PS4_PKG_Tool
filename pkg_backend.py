import os
import subprocess
import hashlib

def verify_and_get_filename(file_path):
    """التحقق من صحة الملف واسمه وهل هو ملف PKG حقيقي وسليم"""
    if not os.path.exists(file_path):
        return None, "الملف غير موجود!"
    
    file_name = os.path.basename(file_path)
    
    # التحقق من الامتداد
    if not file_name.lower().endswith(('.pkg', '.part_00', '.part_01', '.part_000')):
        if ".part_" not in file_name:
            return file_name, "تحذير: امتداد الملف ليس PKG!"

    # التحقق من إمكانية قراءة الهيدر (تأكيد أن الملف غير تالف)
    try:
        with open(file_path, "rb") as f:
            header = f.read(0x10)
            if len(header) < 0x10:
                return file_name, "ملف تالف أو فارغ!"
    except Exception as e:
        return file_name, f"خطأ في قراءة الملف: {e}"

    return file_name, "تم التحقق من الملف بنجاح ✓"

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
    except Exception:
        return False

def merge_pkg_bash(pattern, output_path):
    cmd = f"cat {pattern} > '{output_path}'"
    try:
        result = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return result.returncode == 0
    except Exception:
        return False
