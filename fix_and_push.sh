#!/bin/bash

# 1. التنظيف وتحديث التبعيات
flutter clean
flutter pub get

# 2. إضافة التغييرات والالتزام بها
git add .
git commit -m "Fix build errors and update project dependencies"

# 3. رفع التغييرات إلى الفرع الرئيسي
git push origin main

# 4. إعادة إنشاء Tag جديد لتشغيل البناء مجدداً
TAG_NAME="v2.2.0"
git tag -f $TAG_NAME
git push origin $TAG_NAME --force

