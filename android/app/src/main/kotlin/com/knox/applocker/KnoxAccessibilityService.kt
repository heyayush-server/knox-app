package com.knox.applocker

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.view.accessibility.AccessibilityEvent
import android.util.Log

/**
 * Knox Accessibility Service
 *
 * This is the core detection mechanism for Knox App Lock.
 *
 * How it works:
 * 1. Listens for TYPE_WINDOW_STATE_CHANGED events — fired whenever a new
 *    Activity window becomes foreground.
 * 2. Extracts the package name from the event.
 * 3. Checks if that package is in Knox's locked app list (via LockedAppsCache).
 * 4. If locked → launches LockOverlayActivity to intercept the user.
 *
 * Samsung OneUI notes:
 * - Samsung devices use their own TaskMonitorService which can conflict.
 * - Knox uses the standard AccessibilityService approach which works reliably
 *   on all Samsung OneUI 3.x / 4.x / 5.x / 6.x devices.
 * - The service must be granted in Settings > Accessibility > Knox App Guard.
 * - Samsung's "Adaptive Battery" may restrict background services — users
 *   should whitelist Knox in Battery settings.
 *
 * Android 12+ considerations:
 * - TYPE_WINDOW_STATE_CHANGED is still reliable for Activity-based apps.
 * - Some split-screen and freeform window scenarios may behave differently.
 * - The service cannot monitor apps that run in isolated processes.
 */
class KnoxAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "KnoxAccessibility"

        // Own package — never lock ourselves
        private const val KNOX_PACKAGE = "com.knox.applocker"

        // System packages that should never be locked (would break device)
        private val SYSTEM_BLACKLIST = setOf(
            "com.android.systemui",
            "com.android.launcher",
            "com.sec.android.app.launcher",   // Samsung launcher
            "com.samsung.android.app.launcher",
            "android",
            "com.android.phone",
            "com.android.settings",
            KNOX_PACKAGE
        )

        /**
         * Check if Knox Accessibility Service is currently enabled.
         * Reads the secure settings string that Android maintains.
         */
        fun isEnabled(context: Context): Boolean {
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val expectedComponent = ComponentName(context, KnoxAccessibilityService::class.java)
            val colonSplitter = TextUtils.SimpleStringSplitter(':')
            colonSplitter.setString(enabledServices)

            while (colonSplitter.hasNext()) {
                val componentName = colonSplitter.next()
                try {
                    val enabledComponent = ComponentName.unflattenFromString(componentName)
                    if (enabledComponent != null && enabledComponent == expectedComponent) {
                        return true
                    }
                } catch (_: Exception) {}
            }
            return false
        }
    }

    // Track last locked package to avoid repeated triggers
    private var lastLockedPackage: String? = null
    private var lastEventTime: Long = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Knox Accessibility Service connected")

        // Configure service info programmatically for reliability
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 50L
            flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName.isBlank()) return

        // Skip system and Knox own package
        if (SYSTEM_BLACKLIST.any { packageName.startsWith(it) }) return

        // Skip non-Activity windows (e.g. dialogs from already-allowed app)
        // This prevents re-triggering lock after the user unlocked once
        if (event.className != null) {
            val className = event.className.toString()
            // Only trigger for Activity windows, not PopupWindows/Dialogs
            if (!isActivityWindow(packageName, className)) return
        }

        // Debounce: ignore duplicate events within 500ms
        val now = System.currentTimeMillis()
        if (packageName == lastLockedPackage && (now - lastEventTime) < 500) return

        // Check if this app is in the locked list
        if (LockedAppsCache.isLocked(packageName)) {
            lastLockedPackage = packageName
            lastEventTime = now
            showLockScreen(packageName)
        } else {
            // User navigated away from a locked app — clear grace state
            if (lastLockedPackage != null && lastLockedPackage != packageName) {
                lastLockedPackage = null
            }
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Knox Accessibility Service interrupted")
    }

    /**
     * Check if the window event is from an Activity (not a Dialog/Toast/etc)
     * This reduces false positives in lock triggering.
     */
    private fun isActivityWindow(packageName: String, className: String): Boolean {
        return try {
            val activityInfo: ActivityInfo = packageManager.getActivityInfo(
                ComponentName(packageName, className), 0
            )
            true // If we got ActivityInfo, it's an Activity
        } catch (e: PackageManager.NameNotFoundException) {
            // Class not found as Activity — could be Dialog/Fragment host
            // Still trigger if it's a known app pattern
            !className.contains("Dialog") &&
            !className.contains("Toast") &&
            !className.contains("Popup")
        }
    }

    /**
     * Launch the Knox lock overlay activity.
     * Uses FLAG_ACTIVITY_NEW_TASK since we're launching from a Service.
     * Uses FLAG_ACTIVITY_NO_ANIMATION for immediate appearance.
     */
    private fun showLockScreen(packageName: String) {
        try {
            val appName = getAppName(packageName)
            val intent = Intent(this, LockOverlayActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
                putExtra(LockOverlayActivity.EXTRA_PACKAGE_NAME, packageName)
                putExtra(LockOverlayActivity.EXTRA_APP_NAME, appName)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show lock screen: ${e.message}")
        }
    }

    private fun getAppName(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            packageName
        }
    }
}
