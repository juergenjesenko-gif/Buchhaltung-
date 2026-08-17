# R8/ProGuard-Regeln für den Release-Build.
#
# Flutter und die verwendeten Plugins bringen ihre eigenen Regeln mit (consumer
# rules), deshalb ist hier wenig nötig. Was drinsteht, steht drin, weil es sonst
# im Release-Build kaputtgeht – nicht vorsorglich.

# sqflite nutzt Reflection für die Plugin-Registrierung.
-keep class com.tekartik.sqflite.** { *; }

# Das pdf-Paket ist reines Dart, braucht also keine Regel. image_picker und
# share_plus liefern ihre Regeln selbst mit.

# Warnungen zu fehlenden Play-Core-Klassen: Flutter referenziert die Deferred-
# Components-API, die wir nicht nutzen. Ohne diese Zeilen bricht R8 mit
# "Missing class" ab.
-dontwarn com.google.android.play.core.**
