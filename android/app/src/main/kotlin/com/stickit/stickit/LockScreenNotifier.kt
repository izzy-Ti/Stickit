package com.stickit.stickit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Lock-screen support. Most Android phones don't allow third-party widgets on
 * the lock screen, so notes marked "show on lock screen" are posted as a
 * persistent, publicly-visible notification, which every Android version
 * displays on the lock screen. (The widget itself also declares the keyguard
 * category for devices that support lock-screen widgets.)
 */
object LockScreenNotifier {
    private const val CHANNEL = "lock_notes"
    private const val PREFS = "stickit_lock"
    private const val KEY_IDS = "posted"

    fun sync(ctx: Context) {
        val nm = ctx.getSystemService(NotificationManager::class.java) ?: return
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val previous = prefs.getStringSet(KEY_IDS, emptySet()) ?: emptySet()
        val active = NoteRepo.all(ctx).filter { it.lock }

        if (Build.VERSION.SDK_INT >= 26 && active.isNotEmpty()) {
            val ch = NotificationChannel(CHANNEL, "Lock screen notes", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Notes you chose to show on the lock screen"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            nm.createNotificationChannel(ch)
        }

        for (n in active) {
            val open = PendingIntent.getActivity(
                ctx, n.id.hashCode(), NoteWidgetProvider.openNoteIntent(ctx, n.id),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val text = n.plainText().ifBlank { " " }
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL)
            else @Suppress("DEPRECATION") Notification.Builder(ctx)
            val notif = builder
                .setSmallIcon(R.drawable.ic_stat_note)
                .setContentTitle(n.title.ifBlank { "Note" })
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setColor(n.bg)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setContentIntent(open)
                .build()
            try {
                nm.notify(n.id.hashCode(), notif)
            } catch (_: SecurityException) {
                // Notification permission not granted.
            }
        }

        val activeIds = active.map { it.id }.toSet()
        previous.filterNot { it in activeIds }.forEach { nm.cancel(it.hashCode()) }
        prefs.edit().putStringSet(KEY_IDS, activeIds).apply()
    }
}

/** Restores lock-screen notes after a reboot or app update. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        LockScreenNotifier.sync(ctx)
        NoteWidgetProvider.updateAll(ctx)
    }
}
