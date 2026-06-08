# ── Flutter ──────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── Supabase / Ktor / OkHttp ─────────────────────────────────────────────────
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# ── Google Sign-In ────────────────────────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.api.** { *; }
-dontwarn com.google.api.**

# ── Kotlin serialization (usado por Supabase) ─────────────────────────────────
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class ** {
    @kotlinx.serialization.Serializable *;
}

# ── Geolocator ────────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ── Mobile Scanner / ZXing ───────────────────────────────────────────────────
-keep class com.journeyapps.barcodescanner.** { *; }
-dontwarn com.journeyapps.barcodescanner.**
-keep class com.google.zxing.** { *; }
-dontwarn com.google.zxing.**

# ── File Picker ───────────────────────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**

# ── PDF / Printing ────────────────────────────────────────────────────────────
-keep class com.nativepdf.** { *; }
-dontwarn com.nativepdf.**

# ── Shared Preferences ───────────────────────────────────────────────────────
-keep class androidx.preference.** { *; }

# ── Mantener enums y modelos de datos ────────────────────────────────────────
-keepclassmembers enum * { *; }
-keepclassmembers class * {
    public static ** valueOf(java.lang.String);
    public static **[] values();
}

# ── Crash safety: mantener stack traces legibles ─────────────────────────────
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile
