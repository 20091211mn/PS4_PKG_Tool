#!/bin/bash

# 1. حذف مجلد android القديم لإزالة جميع آثار Android v1 embedding
rm -rf android

# 2. إنشاء هيكلية مجلد أندرويد الحديثة
mkdir -p android/app/src/main/kotlin/com/example/ps4_pkg_tool

# إنشاء ملف settings.gradle بالنظام الحديث
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
    id "com.android.application" version "7.3.0" apply false
    id "org.jetbrains.kotlin.android" version "1.7.10" apply false
}

include ":app"
SETTINGS_EOF

# إنشاء ملف build.gradle الرئيسي
cat << 'ROOT_BUILD_EOF' > android/build.gradle
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(':app')
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
ROOT_BUILD_EOF

# إنشاء ملف app/build.gradle للنسخ الخاصة
cat << 'APP_BUILD_EOF' > android/app/build.gradle
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
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
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

    flavorDimensions "app_type"

    productFlavors {
        official {
            dimension "app_type"
            applicationId "com.example.ps4_pkg_tool"
            resValue "string", "app_name", "PS4 PKG Tool"
        }
        dev {
            dimension "app_type"
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
APP_BUILD_EOF

# إنشاء MainActivity متوافق مع v2
cat << 'MAIN_ACTIVITY_EOF' > android/app/src/main/kotlin/com/example/ps4_pkg_tool/MainActivity.kt
package com.example.ps4_pkg_tool

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
MAIN_ACTIVITY_EOF

# إنشاء AndroidManifest.xml المحدث
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
            android:theme="@android:style/Theme.Black.NoTitleBar"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
MANIFEST_EOF

# 3. إعداد ملفات Workflows المنفصلة لـ GitHub
rm -rf .github/workflows/*
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
        run: flutter build apk --flavor official --target lib/main.dart --release --no-tree-shake-icons

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
        run: flutter build apk --flavor dev --target lib/main.dart --release --no-tree-shake-icons

      - name: Upload Dev Admin APK
        uses: actions/upload-artifact@v4
        with:
          name: Developer-Admin-APK
          path: build/app/outputs/flutter-apk/app-dev-release.apk
DEV_EOF

# 4. حفظ وإرسال التعديلات لـ GitHub
git add .
git commit -m "Completely clean and rebuild Android structure to fix v1 embedding"
git push origin main || git push origin master

