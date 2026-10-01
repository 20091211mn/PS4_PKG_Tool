#!/bin/bash

# 1. تحديث ملف البناء الخاص بـ GitHub Actions بإصدار ثابت ومضمون
mkdir -p .github/workflows
cat << 'WORKFLOW_EOF' > .github/workflows/main.yml
name: Build Android APK

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
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
          flutter-version: '3.16.9'
          channel: 'stable'

      - name: Get Dependencies
        run: flutter pub get

      - name: Build APK
        run: flutter build apk --split-per-abi --no-tree-shake-icons

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: build/app/outputs/flutter-apk/*.apk
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
WORKFLOW_EOF

# 2. رفع التغييرات إلى GitHub وإنشاء إطلاق جديد v2.5.0
git add .github/workflows/main.yml
git commit -m "Fix GitHub workflow with Flutter 3.16.9"
git push origin main

TAG_NAME="v2.5.0"
git tag -f $TAG_NAME
git push origin $TAG_NAME --force

