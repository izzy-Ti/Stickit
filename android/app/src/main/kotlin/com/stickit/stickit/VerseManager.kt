package com.stickit.stickit

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * Built-in "verse of the hour" sticky notes (Bible and Quran). Each is an
 * ordinary note with a `kind` field; its title/body are replaced hourly.
 * Either can be turned off (deleting the note does that) and back on in settings.
 */
object VerseManager {
    const val BIBLE = "bible"
    const val QURAN = "quran"
    private val KINDS = listOf(BIBLE, QURAN)

    private const val PREFS = "stickit_verses"
    private const val HOUR = 60 * 60 * 1000L
    private val main = Handler(Looper.getMainLooper())

    private fun prefs(ctx: Context) =
        ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun noteId(kind: String) = "verse-$kind"

    fun isEnabled(ctx: Context, kind: String) = prefs(ctx).getBoolean("on_$kind", true)

    fun settings(ctx: Context): Map<String, Boolean> = KINDS.associateWith { isEnabled(ctx, it) }

    /** App start: add the default notes on first run, keep the hourly alarm set, refresh if stale. */
    fun start(ctx: Context) {
        val p = prefs(ctx)
        if (!p.getBoolean("seeded", false)) {
            KINDS.filter { isEnabled(ctx, it) }.forEach { addPlaceholder(ctx, it) }
            p.edit().putBoolean("seeded", true).apply()
            changed(ctx)
        }
        schedule(ctx)
        refresh(ctx, force = false)
    }

    fun setEnabled(ctx: Context, kind: String, on: Boolean) {
        if (kind !in KINDS) return
        prefs(ctx).edit().putBoolean("on_$kind", on).apply()
        if (on) {
            if (NoteRepo.find(ctx, noteId(kind)) == null) {
                addPlaceholder(ctx, kind)
                changed(ctx)
            }
            refresh(ctx, force = false)
        } else if (NoteRepo.remove(ctx, noteId(kind))) {
            changed(ctx)
        }
    }

    private fun addPlaceholder(ctx: Context, kind: String) {
        val (title, bg) = when (kind) {
            BIBLE -> "Bible verse" to 0xFFCFE6FBL
            else -> "Quran verse" to 0xFFD5ECD3L
        }
        NoteRepo.addVerseNote(ctx, noteId(kind), kind, title, "Your verse will appear here shortly.", bg)
        prefs(ctx).edit().putLong("at_$kind", 0).apply()
    }

    /** Fetches new verses off the main thread, then writes them on the main thread. */
    fun refresh(ctx: Context, force: Boolean, done: (() -> Unit)? = null) {
        val app = ctx.applicationContext
        val now = System.currentTimeMillis()
        val due = KINDS.filter {
            isEnabled(app, it) && NoteRepo.find(app, noteId(it)) != null &&
                (force || now - prefs(app).getLong("at_$it", 0) >= HOUR - 5 * 60_000)
        }
        if (due.isEmpty()) { done?.invoke(); return }
        Thread {
            val results = due.mapNotNull { k -> runCatching { k to fetch(k) }.getOrNull() }
            main.post {
                var any = false
                for ((k, verse) in results) {
                    if (!isEnabled(app, k)) continue
                    if (NoteRepo.updateText(app, noteId(k), verse.first, verse.second)) {
                        prefs(app).edit().putLong("at_$k", now).apply()
                        any = true
                    }
                }
                if (any) changed(app)
                done?.invoke()
            }
        }.start()
    }

    private fun changed(ctx: Context) {
        NoteWidgetProvider.updateAll(ctx)
        LockScreenNotifier.sync(ctx)
        MainActivity.notifyNotesChanged()
    }

    // ---- network ----

    private fun getJson(url: String): JSONObject {
        val c = URL(url).openConnection() as HttpURLConnection
        c.connectTimeout = 15_000
        c.readTimeout = 15_000
        c.setRequestProperty("Accept", "application/json")
        c.setRequestProperty("User-Agent", "Stickit-Android")
        try {
            if (c.responseCode !in 200..299) error("HTTP ${c.responseCode}")
            return JSONObject(c.inputStream.bufferedReader().use { it.readText() })
        } finally {
            c.disconnect()
        }
    }

    /** Returns (title, body). */
    private fun fetch(kind: String): Pair<String, String> = when (kind) {
        BIBLE -> {
            val d = getJson("https://beta.ourmanna.com/api/v1/get?format=json&order=random")
                .getJSONObject("verse").getJSONObject("details")
            val version = d.optString("version")
            val ref = d.getString("reference") + if (version.isNotBlank()) " ($version)" else ""
            ref to d.getString("text").trim()
        }
        else -> {
            val d = getJson("https://api.alquran.cloud/v1/ayah/random").getJSONObject("data")
            val surah = d.getJSONObject("surah")
            val arabic = d.getString("text").trim()
            val english = runCatching {
                getJson("https://api.alquran.cloud/v1/ayah/${d.getInt("number")}/en.sahih")
                    .getJSONObject("data").getString("text").trim()
            }.getOrNull()
            val title = "${surah.optString("englishName")} ${surah.getInt("number")}:${d.getInt("numberInSurah")}"
            title to (if (english.isNullOrBlank()) arabic else "$arabic\n\n$english")
        }
    }

    // ---- hourly alarm ----

    fun schedule(ctx: Context) {
        val am = ctx.getSystemService(AlarmManager::class.java) ?: return
        val pi = PendingIntent.getBroadcast(
            ctx, 7301, Intent(ctx, VerseAlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // Inexact + non-wakeup: battery friendly, runs roughly hourly while the phone is in use.
        am.setInexactRepeating(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + AlarmManager.INTERVAL_HOUR,
            AlarmManager.INTERVAL_HOUR,
            pi,
        )
    }
}

class VerseAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val pending = goAsync()
        VerseManager.refresh(ctx, force = true) { pending.finish() }
    }
}
