#!/bin/bash

# 1. تحديث Gradle Wrapper إلى الإصدار المطلوبة 8.14
mkdir -p android/gradle/wrapper
cat << 'WRAPPER_EOF' > android/gradle/wrapper/gradle-wrapper.properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14-bin.zip
WRAPPER_EOF

# 2. تحديث android/settings.gradle
cat << 'SETTINGS_EOF' > android/settings.gradle
pluginManagement {
    def flutterSdkPath = {
        def properties = new Properties()
        def propertiesFile = new File(rootDir, 'local.properties')
        if (propertiesFile.exists()) {
            propertiesFile.withReader('UTF-8') { reader -> properties.load(reader) }
        }
        def flutterSdkPath = properties.getProperty('flutter.sdk')
        assert flutterSdkPath != null, "flutter.sdk not set in local.properties"
        return flutterSdkPath
    }()

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.3.0" apply false
    id "org.jetbrains.kotlin.android" version "1.9.22" apply false
}

include ":app"
SETTINGS_EOF

# 3. تحديث ملفات GitHub Workflows وتعديل أوامر البناء لتجاوز التدقيق الصارم
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

      - name: Get Dependencies
        run: flutter pub get

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

      - name: Get Dependencies
        run: flutter pub get

      - name: Build Dev Admin Release APK
        run: flutter build apk --flavor dev --target lib/main.dart --release --no-tree-shake-icons --android-skip-build-dependency-validation

      - name: Upload Dev Admin APK
        uses: actions/upload-artifact@v4
        with:
          name: Developer-Admin-APK
          path: build/app/outputs/flutter-apk/app-dev-release.apk
DEV_EOF

# 4. إرسال التعديلات لـ GitHub
git add .
git commit -m "Upgrade Gradle to 8.14 and enable build dependency validation skip flag"
git push origin main || git push origin master

