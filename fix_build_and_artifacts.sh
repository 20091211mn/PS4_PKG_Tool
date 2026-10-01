#!/bin/bash

# 1. تحديث إعدادات Gradle والاندرويد لتوافق إصدارات Flutter الحديثة
mkdir -p android/app

cat << 'GRADLE_EOF' > android/settings.gradle
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
    id "com.android.application" version "7.3.0" apply false
    id "org.jetbrains.kotlin.android" version "1.7.10" apply false
}

include ":app"
GRADLE_EOF

cat << 'BUILD_EOF' > android/app/build.gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

android {
    namespace "com.example.ps4_pkg_tool"
    compileSdk 34

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_7
        targetCompatibility JavaVersion.VERSION_1_7
    }

    kotlinOptions {
        jvmTarget = '1.7'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.example.ps4_pkg_tool"
        minSdk 21
        targetSdk 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    flavorDimensions "default"
    productFlavors {
        official {
            dimension "default"
            applicationId "com.example.ps4_pkg_tool"
            resValue "string", "app_name", "PS4 PKG Tool"
        }
        dev {
            dimension "default"
            applicationId "com.example.ps4_pkg_tool.dev"
            applicationIdSuffix ".dev"
            resValue "string", "app_name", "PS4 PKG Admin"
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}
BUILD_EOF

# 2. إعداد ملف GitHub Actions لبناء النسختين وحفظهما كملفات Artifacts قابلة للتحميل المباشر
mkdir -p .github/workflows
cat << 'WORKFLOW_EOF' > .github/workflows/main.yml
name: Build All APKs (Artifacts)

on:
  push:
    branches:
      - main
      - master

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
          channel: 'stable'

      - name: Get Dependencies
        run: flutter pub get

      - name: Build Official and Dev APKs
        run: flutter build apk --flavor official --release && flutter build apk --flavor dev --release

      - name: Upload Official APK
        uses: actions/upload-artifact@v4
        with:
          name: Official-User-APK
          path: build/app/outputs/flutter-apk/app-official-release.apk

      - name: Upload Dev Admin APK
        uses: actions/upload-artifact@v4
        with:
          name: Developer-Admin-APK
          path: build/app/outputs/flutter-apk/app-dev-release.apk
WORKFLOW_EOF

# 3. رفع التحديثات إلى GitHub
git add .
git commit -m "Fix Gradle issue and upload APKs directly to Actions Artifacts"
git push origin main || git push origin master

