[app]
title = PS4 PKG Tool
package.name = ps4pkgtool
package.domain = org.test

source.dir = .
source.include_exts = py,png,jpg,kv,atlas,ttf

version = 0.1
requirements = python3,kivy,arabic_reshaper,python-bidi

orientation = portrait
fullscreen = 0
android.permissions = READ_EXTERNAL_STORAGE,WRITE_EXTERNAL_STORAGE,MANAGE_EXTERNAL_STORAGE
android.api = 31
android.minapi = 21

[buildozer]
log_level = 2
warn_on_root = 1
