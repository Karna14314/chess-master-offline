# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Flutter embedding
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

# Stockfish engine
-keep class stockfish.** { *; }

# SQLite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Google Play Core and SplitCompat - don't warn about missing classes
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.gms.common.**
-dontwarn com.google.android.gms.tasks.**

# Keep Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
