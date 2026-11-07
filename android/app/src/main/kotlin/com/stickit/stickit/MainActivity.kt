package com.stickit.stickit

import android.Manifest
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val EXTRA_NOTE_ID = "note_id"
        const val EXTRA_RESIZE_WIDGET = "resize_widget"
        private const val REQ_NOTIF = 4242
        private var channel: MethodChannel? = null

        /** Tells a running Flutter UI that notes changed outside the app (e.g. widget tick). */
        fun notifyNotesChanged() {
            channel?.invokeMethod("notesChanged", null)
        }
    }

    private var initialNoteId: String? = null
    private var initialResize: Map<String, Any>? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialResize = intent?.let(::resizeRequest)
        initialNoteId = if (initialResize == null) intent?.getStringExtra(EXTRA_NOTE_ID) else null
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stickit/native").also {
            it.setMethodCallHandler(::onCall)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        channel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val resize = resizeRequest(intent)
        if (resize != null) {
            channel?.invokeMethod("resizeWidget", resize)
        } else {
            intent.getStringExtra(EXTRA_NOTE_ID)?.let { channel?.invokeMethod("openNote", it) }
        }
    }

    /** {noteId, widgetId, w, h} when launched from a widget's resize button. */
    private fun resizeRequest(intent: Intent): Map<String, Any>? {
        val widgetId = intent.getIntExtra(EXTRA_RESIZE_WIDGET, AppWidgetManager.INVALID_APPWIDGET_ID)
        val noteId = intent.getStringExtra(EXTRA_NOTE_ID)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID || noteId == null) return null
        val (w, h) = WidgetSizes.sizeOf(AppWidgetManager.getInstance(this), widgetId)
        return mapOf("noteId" to noteId, "widgetId" to widgetId, "w" to w, "h" to h)
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadNotes" -> result.success(NoteRepo.raw(this))
            "saveNotes" -> {
                NoteRepo.saveRaw(this, call.arguments as String)
                NoteWidgetProvider.updateAll(this)
                LockScreenNotifier.sync(this)
                result.success(null)
            }
            "initialNoteId" -> {
                result.success(initialNoteId)
                initialNoteId = null
            }
            "initialResize" -> {
                result.success(initialResize)
                initialResize = null
            }
            "pinToHome" -> result.success(
                pinToHome(
                    call.argument<String>("noteId") ?: return result.success(false),
                    call.argument<Int>("w") ?: 2,
                    call.argument<Int>("h") ?: 2,
                    call.argument<Int>("replaces"),
                ),
            )
            "widgetCount" -> result.success(NoteRepo.widgetCount(this, call.arguments as String))
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "startVerses" -> {
                VerseManager.start(this)
                result.success(null)
            }
            "verseSettings" -> result.success(VerseManager.settings(this))
            "setVerseEnabled" -> {
                val kind = call.argument<String>("kind") ?: return result.success(null)
                VerseManager.setEnabled(this, kind, call.argument<Boolean>("on") ?: true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pinToHome(noteId: String, w: Int, h: Int, replaces: Int?): Boolean {
        if (Build.VERSION.SDK_INT < 26) return false
        val mgr = getSystemService(AppWidgetManager::class.java) ?: return false
        if (!mgr.isRequestPinAppWidgetSupported) return false
        val callback = Intent(this, NoteWidgetProvider::class.java)
            .setAction(NoteWidgetProvider.ACTION_PINNED)
            .putExtra(EXTRA_NOTE_ID, noteId)
            .putExtra(NoteWidgetProvider.EXTRA_REPLACES, replaces ?: AppWidgetManager.INVALID_APPWIDGET_ID)
        // Mutable so the launcher can attach the new widget id.
        val pi = PendingIntent.getBroadcast(
            this, noteId.hashCode(), callback,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )
        return mgr.requestPinAppWidget(ComponentName(this, WidgetSizes.providerFor(w, h)), null, pi)
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_NOTIF) {
            pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
    }
}
