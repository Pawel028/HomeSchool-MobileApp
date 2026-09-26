# HOMESCHOOLING: baseline release proguard/R8 rules.
# build.gradle.kts enables minifyEnabled + shrinkResources for the release
# build type, which requires this file to exist (it was missing from the
# initial repo delivery). The Flutter Gradle plugin already ships consumer
# keep rules for the engine itself, so this file only needs to cover our
# plugin dependencies that do reflection/JNI/native crypto.

# flutter_secure_storage (Android Keystore + EncryptedSharedPreferences)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn javax.crypto.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# dio (uses reflection for some codecs / multipart handling)
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep annotations / generic signatures Play Core & AndroidX sometimes need
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
