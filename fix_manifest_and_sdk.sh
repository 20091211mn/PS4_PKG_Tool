#!/bin/bash

# 1. تحديث android/app/build.gradle مع رفع compileSdk إلى 36 وإضافة manifestPlaceholders
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
    compileSdk 36

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
        targetSdk 36
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    flavorDimensions "app_type"

    productFlavors {
        official {
            dimension "app_type"
            applicationId "com.example.ps4_pkg_tool"
            manifestPlaceholders = [app_name: "PS4 PKG Tool"]
        }
        dev {
            dimension "app_type"
            applicationId "com.example.ps4_pkg_tool.dev"
            applicationIdSuffix ".dev"
            manifestPlaceholders = [app_name: "PS4 PKG Admin"]
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

# 2. تحديث AndroidManifest.xml المباشر بطلب الأذونات واسم التطبيق
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

# 3. إرسال التحديثات لـ GitHub
git add .
git commit -m "Update compileSdk to 36 and fix manifestPlaceholders for app_name"
git push origin main || git push origin master

