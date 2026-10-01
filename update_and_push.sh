#!/bin/bash

# إضافة التعديلات إلى git
git add .

# إنشاء commit بالرسالة
git commit -m "Update main.dart with working split and merge features"

# رفع التعديلات إلى الفرع الرئيسي
git push origin main

# تحديث الـ Tag لإعادة تشغيل بناء التطبيق تلقائياً
git tag -f v2.1.8
git push origin v2.1.8 --force

