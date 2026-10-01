#!/bin/bash

# 1. إصلاح ملف AndroidManifest.xml للتخلص من خطأ Android v1 embedding
mkdir -p android/app/src/main
cat << 'MANIFEST_EOF' > android/app/src/main/AndroidManifest.xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>

    <application
        android:label="${app_name}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <!-- تحديث Flutter Embedding إلى V2 -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
MANIFEST_EOF

# 2. حرق ملفات Workflow القديمة وإنشاء ملفين منفصلين
rm -rf .github/workflows/*
mkdir -p .github/workflows

# أ) ملف البناء الخاص بالنسخة الرسمية (Official User)
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

      - name: Get Dependencies
        run: flutter pub get

      - name: Build Official Release APK
        run: flutter build apk --flavor official --target lib/main.dart --release --no-tree-shake-icons

      - name: Upload Official APK
        uses: actions/upload-artifact@v4
        with:
          name: Official-User-APK
          path: build/app/outputs/flutter-apk/app-official-release.apk
OFFICIAL_EOF

# ب) ملف البناء الخاص بنسخة المطور (Developer Admin)
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

      - name: Get Dependencies
        run: flutter pub get

      - name: Build Dev Admin Release APK
        run: flutter build apk --flavor dev --target lib/main.dart --release --no-tree-shake-icons

      - name: Upload Dev Admin APK
        uses: actions/upload-artifact@v4
        with:
          name: Developer-Admin-APK
          path: build/app/outputs/flutter-apk/app-dev-release.apk
DEV_EOF

# 3. إرسال التحديثات لـ GitHub
git add .
git commit -m "Fix Android v1 embedding issue and split workflows into separate files"
git push origin main || git push origin master

