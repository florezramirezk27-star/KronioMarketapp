# Reglas de ProGuard / R8.
#
# Flutter ya trae sus propias reglas y se aplican solas; este archivo esta
# para las dependencias de la app que R8 no puede resolver por su cuenta.

# Reglas por defecto de Android que suelen Needed cuando se usa R8.
-dontwarn com.google.errorprone.annotations.**
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Conserva los nombres de clase para que los stack traces sean legibles.
-keepnames class * extends java.lang.Throwable

# `shared_preferences` usa SharedPreferences de Android, sin reglas especiales.
# `intl` accede a datos de locale por reflection en algunos casos.
-keep class com.andyroid.** { *; }
