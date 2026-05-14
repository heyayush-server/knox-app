package com.knox.applocker

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Knox Lock Overlay Activity
 *
 * This Activity is displayed on top of locked apps when the user tries to open them.
 *
 * Key design decisions:
 * - Uses its own Flutter engine (created fresh) to render the auth UI.
 * - showWhenLocked=true: displayed even over the device lock screen.
 * - excludeFromRecents=true: won't appear in the Android recents screen.
 * - launchMode=singleTask: ensures only one lock overlay is shown at a time.
 *
 * On successful authentication:
 * - Calls finish() to dismiss the overlay and let the user access the app.
 *
 * On back press:
 * - Goes to home screen (doesn't allow bypassing via back button).
 *
 * FLAG_SECURE is set to prevent screenshots of PIN input.
 */
class LockOverlayActivity : FlutterActivity() {

    companion object {
        const val EXTRA_PACKAGE_NAME = "package_name"
        const val EXTRA_APP_NAME = "app_name"
        private const val CHANNEL = "com.knox.applocker/lock_overlay"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Prevent screenshots of PIN input screen
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )

        // Keep screen on while lock is displayed
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val packageName = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: ""
        val appName = intent.getStringExtra(EXTRA_APP_NAME) ?: packageName

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // Flutter calls this after successful auth
                "onAuthSuccess" -> {
                    // Mark this app as temporarily unlocked (grace period)
                    LockedAppsCache.setGracePeriod(packageName)
                    result.success(null)
                    finish()
                }
                // Flutter calls this to get which app we're locking
                "getLockInfo" -> {
                    result.success(mapOf(
                        "packageName" to packageName,
                        "appName" to appName
                    ))
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Override back press to prevent bypassing lock screen.
     * Instead of going back (which might show the locked app),
     * we go to the home screen.
     */
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Go to home screen instead of back
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        // Don't call super.onBackPressed() — never allow back bypass
    }

    /**
     * Route this activity to the /auth screen.
     * App info (packageName, appName) is supplied by the getLockInfo MethodChannel call
     * that the Flutter AuthScreen makes on init, rather than via URL params,
     * since FlutterActivity.getInitialRoute() has limited query-param support.
     */
    override fun getInitialRoute(): String = "/auth"
}
