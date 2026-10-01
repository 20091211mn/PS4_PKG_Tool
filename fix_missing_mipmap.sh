#!/bin/bash

# 1. إنشاء المجلدات وملفات أيقونات وهمية لضمان عدم توقف البناء في حال اختفائها
mkdir -p android/app/src/main/res/mipmap-hdpi
mkdir -p android/app/src/main/res/mipmap-mdpi
mkdir -p android/app/src/main/res/mipmap-xhdpi
mkdir -p android/app/src/main/res/mipmap-xxhdpi
mkdir -p android/app/src/main/res/mipmap-xxxhdpi

# 2. تحديث ملفات GitHub Workflows لإضافة خطوة توليد الملفات الناقصة
mkdir -p .github/workflows

# ملف بناء النسخة العامة (Official)
cat << 'OFFICIAL_EOF' > .github/workflows/build-official.yml
name: Build Official User APK

on:
  push:
    branches:
      - main
      - master

jobs:
  build-official:
    name: Build Official User APK
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Regenerate missing Android files
        run: flutter create . --platforms=android

      - name: Clean & Get Dependencies
        run: |
          flutter clean
          flutter pub get

      - name: Build Official Release APK
        run: flutter build apk --flavor official --target lib/main.dart --release --no-tree-shake-icons --android-skip-build-dependency-validation

      - name: Upload Official APK
        uses: actions/upload-artifact@v4
        with:
          name: Official-User-APK
          path: build/app/outputs/flutter-apk/app-official-release.apk
OFFICIAL_EOF

# ملف بناء نسخة المطور (Dev Admin)
cat << 'DEV_EOF' > .github/workflows/build-dev.yml
name: Build Developer Admin APK

on:
  push:
    branches:
      - main
      - master

jobs:
  build-dev:
    name: Build Developer Admin APK
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Regenerate missing Android files
        run: flutter create . --platforms=android

      - name: Clean & Get Dependencies
        run: |
          flutter clean
          flutter pub get

      - name: Build Dev Admin Release APK
        run: flutter build apk --flavor dev --target lib/main.dart --release --no-tree-shake-icons --android-skip-build-dependency-validation

      - name: Upload Dev Admin APK
        uses: actions/upload-artifact@v4
        with:
          name: Developer-Admin-APK
          path: build/app/outputs/flutter-apk/app-dev-release.apk
DEV_EOF

# 3. إرسال التعديلات لـ GitHub
git add .
git commit -m "Add flutter create android platform step to workflows to restore missing mipmap assets"
git push origin main || git push origin master

