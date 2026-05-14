# Knox App Lock ProGuard Rules
# ─────────────────────────────────────────────────────────────────────────────

# ── Flutter ───────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── Knox Core ─────────────────────────────────────────────────────────────────
-keep class com.knox.applocker.** { *; }

# ── Android Keystore (never obfuscate crypto classes) ────────────────────────
-keep class android.security.keystore.** { *; }
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# ── Biometric ─────────────────────────────────────────────────────────────────
-keep class androidx.biometric.** { *; }

# ── Hive (Flutter secure storage uses reflection) ─────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class com.it_nomads.fluttersecurestorage.ciphers.** { *; }

# ── local_auth ────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.localauth.** { *; }

# ── Accessibility Service ─────────────────────────────────────────────────────
-keep class * extends android.accessibilityservice.AccessibilityService { *; }

# ── BroadcastReceiver ─────────────────────────────────────────────────────────
-keep class * extends android.content.BroadcastReceiver { *; }

# ── Services ──────────────────────────────────────────────────────────────────
-keep class * extends android.app.Service { *; }
-keep class * extends android.app.Activity { *; }

# ── Remove logging in release ─────────────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
}

# ── Keep R classes ────────────────────────────────────────────────────────────
-keepclassmembers class **.R$* {
    public static <fields>;
}
