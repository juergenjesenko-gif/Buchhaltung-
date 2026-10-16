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

# Google ML Kit Texterkennung (ReceiptTextChannel). Im Release-Build mit R8
# brach die Erkennung auf dem Pixel 10 mit einer NullPointerException ab
# (Gerätetest 2026-10-12, Builds 69 und 74): ML Kit findet seine Komponenten
# und das gebündelte Modell über Reflexion. Nicht verkleinern/umbenennen.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.mlkit.**

# Dokumentenscanner (DocumentScannerChannel, FA-2.51): Play-Dienste-Modul,
# Ergebnis über Parcelable (GmsDocumentScanningResult). Vorsorglich gleich
# behandelt wie die übrigen ML-Kit-Klassen; Gerätetest P-D37.
-keep class com.google.mlkit.vision.documentscanner.** { *; }
-keep class com.google.android.gms.internal.mlkit_docscan** { *; }
