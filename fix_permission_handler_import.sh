#!/bin/bash

# 1. تحديث pubspec.yaml لإضافة permission_handler
cat << 'PUBSPEC_EOF' > pubspec.yaml
name: ps4_pkg_tool
description: "A Flutter application for managing PS4 PKG files."
publish_to: 'none'

version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  file_picker: ^8.1.2
  permission_handler: ^11.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
PUBSPEC_EOF

# 2. إضافة import لـ permission_handler أعلى ملف lib/main.dart إن لم يكن موجوداً
if grep -q "package:permission_handler/permission_handler.dart" lib/main.dart; then
    echo "Import already exists in main.dart"
else
    sed -i '1i import '\''package:permission_handler/permission_handler.dart'\'';' lib/main.dart
    echo "Added permission_handler import to lib/main.dart"
fi

# 3. حفظ وإرسال التعديلات إلى GitHub
git add .
git commit -m "Add permission_handler package and import in main.dart to resolve build errors"
git push origin main || git push origin master

