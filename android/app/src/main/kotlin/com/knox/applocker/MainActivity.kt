package com.knox.applocker

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Knox MainActivity
 *
 * Hosts two MethodChannels:
 * 1. com.knox.applocker/apps       — installed app list, icons
 * 2. com.knox.applocker/permissions — permission checks and navigation
 * 3. com.knox.applocker/biometrics  — enrollment hash (see BiometricHelper)
 *
 * FLAG_SECURE is set here to prevent screenshots of sensitive screens.
 * This is enforced for the entire app. Individual screens can override via
 * platform channels if needed.
 */
class MainActivity : FlutterActivity() {

    companion object {
        const val APPS_CHANNEL = "com.knox.applocker/apps"
        const val PERMISSIONS_CHANNEL = "com.knox.applocker/permissions"
        const val BIOMETRICS_CHANNEL = "com.knox.applocker/biometrics"
        const val SYNC_CHANNEL = "com.knox.applocker/sync"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // FLAG_SECURE: prevents screenshots and screen recording of Knox
        // This protects PIN input and app list from being captured
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        setupAppsChannel(flutterEngine)
        setupPermissionsChannel(flutterEngine)
        setupBiometricsChannel(flutterEngine)
        setupSyncChannel(flutterEngine)

        // Start Knox Guard service on app open
        startGuardServiceIfNeeded()
    }

    // ─── Apps Channel ──────────────────────────────────────────────────────────

    private fun setupAppsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APPS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                    result.success(AppHelper.getInstalledApps(this, includeSystem))
                }
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    result.success(AppHelper.getAppIconBytes(this, packageName))
                }
                else -> result.notImplemented()
            }
        }
    }

    // ─── Permissions Channel ──────────────────────────────────────────────────

    private fun setupPermissionsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PERMISSIONS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // ── Usage Stats ───────────────────────────────────────────────
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "openUsageStatsSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    })
                    result.success(null)
                }

                // ── Overlay ───────────────────────────────────────────────────
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "openOverlaySettings" -> {
                    startActivity(Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    ).apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK })
                    result.success(null)
                }

                // ── Accessibility ─────────────────────────────────────────────
                "hasAccessibilityPermission" -> {
                    result.success(KnoxAccessibilityService.isEnabled(this))
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    })
                    result.success(null)
                }

                // ── Guard Service ─────────────────────────────────────────────
                "isGuardServiceRunning" -> {
                    result.success(KnoxGuardService.isRunning)
                }
                "startGuardService" -> {
                    startGuardServiceIfNeeded()
                    result.success(null)
                }
                "stopGuardService" -> {
                    stopService(Intent(this, KnoxGuardService::class.java))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ─── Biometrics Channel ───────────────────────────────────────────────────

    private fun setupBiometricsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BIOMETRICS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getEnrollmentHash" -> {
                    // Returns a hash that changes when biometric enrollment changes.
                    // Uses KeyStore key invalidation strategy for Android 23+.
                    val hash = BiometricHelper.getEnrollmentHash(this)
                    result.success(hash)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ─── Sync Channel ─────────────────────────────────────────────────────────
    // Keeps Kotlin LockedAppsCache in sync when Flutter toggles lock state

    private fun setupSyncChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYNC_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setLocked" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val locked = call.argument<Boolean>("locked") ?: false
                    LockedAppsCache.setLocked(this, packageName, locked)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            ) == AppOpsManager.MODE_ALLOWED
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                packageName
            ) == AppOpsManager.MODE_ALLOWED
        }
    }

    private fun startGuardServiceIfNeeded() {
        if (!KnoxGuardService.isRunning) {
            try {
                val serviceIntent = Intent(this, KnoxGuardService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
            } catch (e: Exception) {
                // Service start may fail in some restricted environments
                e.printStackTrace()
            }
        }
    }
}
