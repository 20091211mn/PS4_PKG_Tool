[app]
title = PS4 PKG Studio Native
package.name = ps4pkgstudionative
package.domain = org.ps4pkg
source.dir = .
source.include_exts = py,png,jpg,kv,atlas
version = 1.0.0
requirements = python3==3.11.0,kivy

orientation = portrait
fullscreen = 0

android.permissions = READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE,MANAGE_EXTERNAL_STORAGE,INTERNET
android.api = 33
android.minapi = 21
android.ndk = 25b
android.accept_sdk_license = True
