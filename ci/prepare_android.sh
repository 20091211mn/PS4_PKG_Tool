set -e
cd android
sed -i -E 's/(id "com.android.application" version ")[0-9.]+(")/\18.11.1\2/' settings.gradle
sed -i -E 's/(id "org.jetbrains.kotlin.android" version ")[0-9.]+(")/\12.1.0\2/' settings.gradle
sed -i -E 's#gradle-[0-9.]+-(all|bin).zip#gradle-8.14.3-all.zip#' gradle/wrapper/gradle-wrapper.properties
sed -i -E 's/compileSdk(Version)?[ =]+[^ ]+/compileSdk = 36/' app/build.gradle
sed -i '/applicationIdSuffix/d' app/build.gradle
sed -i 's/com\.example\.ps4_pkg_tool\.dev/com.ps4pkg.admin/g; s/com\.example\.ps4_pkg_tool/com.ps4pkg.studio/g' app/build.gradle
D=app/src/main
NEW=$D/kotlin/com/ps4pkg/studio
mkdir -p $NEW
for f in $(find $D -name 'MainActivity.*'); do
  if [ "$f" != "$NEW/MainActivity.kt" ]; then cp "$f" $NEW/MainActivity.kt; rm "$f"; fi
done
sed -i 's/^package .*/package com.ps4pkg.studio/' $NEW/MainActivity.kt
echo "== versions"; grep -n "version" settings.gradle
cat gradle/wrapper/gradle-wrapper.properties
grep -n "compileSdk\|applicationId\|namespace" app/build.gradle
