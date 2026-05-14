package com.knox.applocker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Knox Boot Receiver
 *
 * Automatically restarts the Knox Guard Service when the device boots.
 * This ensures app protection is active immediately after reboot without
 * requiring the user to manually open Knox.
 *
 * Registered for:
 * - android.intent.action.BOOT_COMPLETED       — standard boot
 * - android.intent.action.QUICKBOOT_POWERON    — HTC/Samsung quick boot
 * - com.htc.intent.action.QUICKBOOT_POWERON    — legacy HTC quick boot
 *
 * Samsung OneUI note:
 * Samsung's Auto-start management may block this receiver.
 * Users can whitelist Knox in: Settings > Apps > Knox > Battery > Allow background activity
 * OR: Settings > Device care > Battery > App power management > Add Knox to exclusions
 *
 * The receiver checks if the user has completed Knox setup before starting
 * the service — no point running the guard if Knox hasn't been configured.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "KnoxBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action

        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        Log.d(TAG, "Boot completed — starting Knox Guard")

        // Check if Knox setup is complete before starting
        // We read from SharedPreferences directly (secure_storage uses EncryptedSharedPreferences)
        // The actual secure check happens inside the Flutter engine on next launch
        val prefs = context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE)
        val setupComplete = prefs.getString("knox_setup_complete", null)

        if (setupComplete != "true") {
            Log.d(TAG, "Knox setup not complete — skipping auto-start")
            return
        }

        // Reload locked apps cache from Hive storage
        LockedAppsCache.reload(context)

        // Start foreground guard service
        try {
            val serviceIntent = Intent(context, KnoxGuardService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.d(TAG, "Knox Guard Service started after boot")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Knox Guard after boot: ${e.message}")
        }
    }
}
