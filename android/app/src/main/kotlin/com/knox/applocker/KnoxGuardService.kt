package com.knox.applocker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Knox Guard Foreground Service
 *
 * Keeps Knox alive in the background to ensure continuous app protection.
 *
 * Android battery optimization can kill background processes. A foreground
 * service with a persistent notification is the most reliable method to
 * prevent this on Android 8+.
 *
 * Samsung OneUI notes:
 * - OneUI's "Adaptive Battery" aggressively kills background services.
 * - Users must add Knox to "Never sleeping apps" in Battery settings:
 *   Settings > Battery > Background usage limits > Never sleeping apps
 * - Alternatively: Settings > Device care > Battery > More battery settings >
 *   Sleeping apps > Remove Knox from sleeping apps list.
 *
 * The notification is minimal and non-intrusive — just a status indicator.
 * It cannot be dismissed (ongoing notification) since it's tied to the service.
 */
class KnoxGuardService : Service() {

    companion object {
        const val CHANNEL_ID = "knox_guard_channel"
        const val NOTIFICATION_ID = 1001
        var isRunning = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())

        // Reload locked apps from shared storage
        LockedAppsCache.reload(this)

        // START_STICKY: Service is restarted if killed by system
        // The OS will re-deliver the last intent on restart
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()

        // Self-restart on destroy (defense against aggressive battery optimization)
        // Only on older APIs; Android 8+ foreground services are managed differently
        val restartIntent = Intent(applicationContext, KnoxGuardService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(restartIntent)
        } else {
            startService(restartIntent)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(getString(R.string.notification_text))
            .setSmallIcon(R.drawable.ic_shield_notification)
            .setContentIntent(openAppIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN) // Minimal visibility
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setSilent(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_MIN // Lowest importance = no sound, no popup
            ).apply {
                description = getString(R.string.notification_channel_desc)
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }

            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
