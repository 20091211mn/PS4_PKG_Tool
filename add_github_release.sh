#!/bin/bash

# 1. تحديث workflow النسخة الرسمية ليشمل النشر التلقائي في Releases
cat << 'OFFICIAL_EOF' > .github/workflows/build-official.yml
name: Build and Release Official APK

on:
  push:
    branches:
      - main
      - master

permissions:
  contents: write

jobs:
  build-and-release:
    name: Build & Release Official APK
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

      - name: Upload Artifacts
        uses: actions/upload-artifact@v4
        with:
          name: Official-User-APK
          path: build/app/outputs/flutter-apk/app-official-release.apk

      - name: Create GitHub Release & Upload APK
        uses: softprops/action-gh-release@v1
        with:
          tag_name: v1.0.${{ github.run_number }}
          name: PS4 PKG Tool Official v1.0.${{ github.run_number }}
          body: "النسخة الرسمية العامة لتطبيق PS4 PKG Tool جاهزة للتحميل المباشر."
          files: build/app/outputs/flutter-apk/app-official-release.apk
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
OFFICIAL_EOF

# 2. دفع التعديلات إلى GitHub
git add .
git commit -m "Configure automated GitHub Releases deployment for official APK"
git push origin main || git push origin master

