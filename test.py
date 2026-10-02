from pkg_backend import get_pkg_info, calculate_md5, split_pkg_bash, merge_pkg_bash

# استبدل هذا المسار بمسار ملف PKG موجود لديك فعلياً
selected_file_path = "/sdcard/Download/game.pkg"

# 1. فحص بيانات الملف
info = get_pkg_info(selected_file_path)
print("--- بيانات الملف ---")
print(f"اسم الملف: {info.get('file_name')}")
print(f"الحجم: {info.get('file_size_gb')} GB")
print(f"Title ID: {info.get('title_id')}")

# 2. حساب الـ MD5 (اختياري للملفات الكبيرة)
checksum = calculate_md5(selected_file_path)
print(f"MD5 Checksum: {checksum}")
