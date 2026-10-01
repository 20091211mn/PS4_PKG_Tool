#!/bin/bash

# 1. إعداد مجلد gradle/wrapper وتثبيت إصدار Gradle 8.3
mkdir -p android/gradle/wrapper
cat << 'WRAPPER_EOF' > android/gradle/wrapper/gradle-wrapper.properties
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.3-bin.zip
WRAPPER_EOF

# 2. تحديث android/settings.gradle لإستخدام إصدارات متوافقة الحديثة
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
    id "com.android.application" version "8.1.0" apply false
    id "org.jetbrains.kotlin.android" version "1.8.22" apply false
}

include ":app"
SETTINGS_EOF

# 3. تحديث android/app/build.gradle
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
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = '17'
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

# 4. رفع التعديلات لـ GitHub
git add .
git commit -m "Upgrade Gradle wrapper to 8.3 and Kotlin plugin to 1.8.22 to fix compatibility"
git push origin main || git push origin master

