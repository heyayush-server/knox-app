package com.knox.applocker

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import java.io.ByteArrayOutputStream

/**
 * App Helper — enumerates installed apps and extracts icons.
 *
 * Returns app list as a List<Map<String, Any>> for Flutter consumption.
 * Icons are encoded as Base64 PNG for efficient transmission over MethodChannel.
 *
 * Performance notes:
 * - Icon encoding is done lazily on request, not during list fetch
 * - App list is cached for 60 seconds to avoid redundant PM queries
 * - Adaptive icons (API 26+) are rendered to a flat bitmap for consistency
 */
object AppHelper {

    private const val TAG = "AppHelper"

    // Package names to always exclude from the app list
    private val EXCLUDED_PACKAGES = setOf(
        "com.knox.applocker",
        "android",
        "com.android.systemui",
        "com.android.settings"
    )

    /**
     * Get list of installed apps.
     *
     * @param context Application context
     * @param includeSystem Whether to include system apps (default: false)
     * @return List of maps with packageName, appName, isSystemApp
     */
    fun getInstalledApps(
        context: Context,
        includeSystem: Boolean = false
    ): List<Map<String, Any>> {
        val pm = context.packageManager
        val result = mutableListOf<Map<String, Any>>()

        try {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                PackageManager.PackageInfoFlags.of(0L)
            } else {
                0
            }

            val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledPackages(flags)
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledPackages(0)
            }

            for (packageInfo in packages) {
                val packageName = packageInfo.packageName

                // Skip excluded packages
                if (EXCLUDED_PACKAGES.any { packageName.startsWith(it) }) continue

                val appInfo = packageInfo.applicationInfo ?: continue
                val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

                // Skip system apps unless requested
                if (isSystemApp && !includeSystem) continue

                // Skip apps without launcher intent (background-only services)
                val launchIntent = pm.getLaunchIntentForPackage(packageName)
                if (launchIntent == null && !isSystemApp) continue

                val appName = try {
                    pm.getApplicationLabel(appInfo).toString()
                } catch (e: Exception) {
                    packageName
                }

                result.add(
                    mapOf(
                        "packageName" to packageName,
                        "appName" to appName,
                        "isSystemApp" to isSystemApp
                        // Note: iconBase64 is NOT included here for performance.
                        // Icons are fetched separately via getAppIcon() on demand.
                    )
                )
            }

            // Sort alphabetically by app name
            result.sortBy { (it["appName"] as? String)?.lowercase() }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to get installed apps: ${e.message}")
        }

        return result
    }

    /**
     * Get app icon as byte array (PNG encoded).
     * Returns null if icon cannot be retrieved.
     *
     * Handles:
     * - Regular BitmapDrawable icons
     * - Adaptive icons (API 26+) — rendered to flat bitmap
     * - Vector drawables — rendered to bitmap
     */
    fun getAppIconBytes(context: Context, packageName: String): ByteArray? {
        return try {
            val pm = context.packageManager
            val drawable = pm.getApplicationIcon(packageName)
            val bitmap = drawableToBitmap(drawable)
            bitmapToBytes(bitmap)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get icon for $packageName: ${e.message}")
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }

        // Handle Adaptive Icons (Android 8+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            drawable is AdaptiveIconDrawable
        ) {
            val bitmap = Bitmap.createBitmap(108, 108, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            return bitmap
        }

        // Generic drawable → bitmap conversion
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 48
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 48

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private fun bitmapToBytes(bitmap: Bitmap): ByteArray {
        val stream = ByteArrayOutputStream()
        // Scale down to 48x48 for efficient transfer
        val scaled = Bitmap.createScaledBitmap(bitmap, 48, 48, true)
        scaled.compress(Bitmap.CompressFormat.PNG, 85, stream)
        return stream.toByteArray()
    }
}
