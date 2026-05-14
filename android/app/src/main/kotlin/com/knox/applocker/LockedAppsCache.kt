package com.knox.applocker

import android.content.Context
import android.util.Log

/**
 * Locked Apps Cache
 *
 * Provides a fast in-memory cache of locked package names that can be
 * accessed by both the KnoxAccessibilityService and LockOverlayActivity
 * without going through Flutter's Dart/Hive layer.
 *
 * Data flow:
 * 1. Flutter (Dart/Hive) stores locked apps → Hive box on disk
 * 2. On service start or Flutter→Kotlin bridge call, this cache is refreshed
 * 3. AccessibilityService reads from this cache (fast, no IPC needed)
 *
 * Persistence strategy:
 * Hive stores data in app's files directory as binary files. We maintain
 * a companion SharedPreferences mirror that KotlinCode can read directly.
 * Flutter writes to both Hive (primary) and SharedPreferences (mirror) on
 * every lock/unlock toggle.
 *
 * Grace period:
 * After successful authentication, an app is granted a grace period where
 * it won't trigger the lock screen again immediately. This prevents the
 * lock from re-triggering when the user briefly switches away and back.
 */
object LockedAppsCache {

    private const val TAG = "LockedAppsCache"
    private const val PREFS_NAME = "knox_locked_apps"
    private const val KEY_LOCKED_APPS = "locked_packages"

    // In-memory set of locked package names — fast O(1) lookup
    private val lockedPackages = mutableSetOf<String>()

    // Grace period map: packageName → expiry timestamp (ms)
    private val gracePeriodMap = mutableMapOf<String, Long>()

    // Grace period duration: 3 seconds after unlock
    private const val GRACE_PERIOD_MS = 3000L

    /**
     * Reload locked apps from SharedPreferences mirror.
     * Called on service start and boot.
     */
    fun reload(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val stored = prefs.getStringSet(KEY_LOCKED_APPS, emptySet()) ?: emptySet()
            synchronized(lockedPackages) {
                lockedPackages.clear()
                lockedPackages.addAll(stored)
            }
            Log.d(TAG, "Loaded ${lockedPackages.size} locked apps")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reload locked apps: ${e.message}")
        }
    }

    /**
     * Check if a package is locked.
     * Also checks grace period — if recently unlocked, returns false.
     */
    fun isLocked(packageName: String): Boolean {
        // Check grace period first
        val graceExpiry = gracePeriodMap[packageName]
        if (graceExpiry != null && System.currentTimeMillis() < graceExpiry) {
            return false // In grace period — don't re-lock
        }

        return synchronized(lockedPackages) {
            lockedPackages.contains(packageName)
        }
    }

    /**
     * Update the locked state for a package (called from Flutter via platform channel).
     * Also persists to SharedPreferences.
     */
    fun setLocked(context: Context, packageName: String, locked: Boolean) {
        synchronized(lockedPackages) {
            if (locked) {
                lockedPackages.add(packageName)
            } else {
                lockedPackages.remove(packageName)
            }
        }
        persist(context)
    }

    /**
     * Set grace period after successful authentication.
     * The app won't be re-locked for GRACE_PERIOD_MS milliseconds.
     */
    fun setGracePeriod(packageName: String) {
        gracePeriodMap[packageName] = System.currentTimeMillis() + GRACE_PERIOD_MS
        Log.d(TAG, "Grace period set for $packageName")
    }

    /**
     * Get all currently locked packages.
     */
    fun getLockedPackages(): Set<String> = synchronized(lockedPackages) {
        lockedPackages.toSet()
    }

    private fun persist(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                .putStringSet(KEY_LOCKED_APPS, synchronized(lockedPackages) {
                    lockedPackages.toSet()
                })
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist locked apps: ${e.message}")
        }
    }
}
