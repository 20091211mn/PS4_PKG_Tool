[app]
title = PS4 PKG Tool
package.name = ps4pkgtool
package.domain = org.test

source.dir = .
source.include_exts = py,png,jpg,kv,atlas,ttf

version = 0.1
requirements = python3,kivy==2.3.0,arabic_reshaper,python-bidi,android

orientation = portrait
fullscreen = 0
android.permissions = READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE,MANAGE_EXTERNAL_STORAGE
android.api = 33
android.minapi = 21

[buildozer]
log_level = 2
warn_on_root = 1
