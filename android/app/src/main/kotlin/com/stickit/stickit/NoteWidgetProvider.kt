package com.stickit.stickit

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews

/**
 * Resizable home-screen (and, where supported, lock-screen) sticky-note widget.
 * Open so the same widget can be registered in several sizes (see WidgetSizes).
 */
open class NoteWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PINNED = "com.stickit.stickit.WIDGET_PINNED"
        const val ACTION_TOGGLE = "com.stickit.stickit.TOGGLE_ITEM"
        const val EXTRA_INDEX = "item_index"
        /** Old widget to retire once a resized copy has been placed. */
        const val EXTRA_REPLACES = "replaces_widget"
        /** Binding value for a widget that was replaced by a resized copy. */
        const val REPLACED = "__replaced__"

        private const val MUTABLE =
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        private const val IMMUTABLE =
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        fun updateAll(ctx: Context) {
            val mgr = AppWidgetManager.getInstance(ctx)
            val ids = WidgetSizes.allWidgetIds(ctx)
            if (ids.isEmpty()) return
            ids.forEach { update(ctx, mgr, it) }
            @Suppress("DEPRECATION")
            mgr.notifyAppWidgetViewDataChanged(ids, R.id.list)
        }

        fun openNoteIntent(ctx: Context, noteId: String?): Intent =
            Intent(ctx, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("stickit://note/${noteId ?: ""}")
                putExtra(MainActivity.EXTRA_NOTE_ID, noteId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }

        fun resizeIntent(ctx: Context, noteId: String, widgetId: Int): Intent =
            openNoteIntent(ctx, noteId).apply {
                data = Uri.parse("stickit://resize/$widgetId")
                putExtra(MainActivity.EXTRA_RESIZE_WIDGET, widgetId)
            }

        /** The widget title view for a font (custom fonts live in the layout). */
        private fun titleIdFor(font: String?) = when (font) {
            "hand" -> R.id.title_hand
            "marker" -> R.id.title_marker
            else -> R.id.title
        }

        /** Row layout for a font (custom fonts live in the layout). */
        fun itemLayoutFor(font: String?) = when (font) {
            "hand" -> R.layout.widget_item_hand
            "marker" -> R.layout.widget_item_marker
            else -> R.layout.widget_item
        }

        fun update(ctx: Context, mgr: AppWidgetManager, widgetId: Int) {
            val noteId = NoteRepo.noteForWidget(ctx, widgetId)
            val note = noteId?.let { NoteRepo.find(ctx, it) }
            val views = RemoteViews(ctx.packageName, R.layout.widget_note)

            val opts = mgr.getAppWidgetOptions(widgetId)
            val wDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).takeIf { it > 0 } ?: 180
            val hDp = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).takeIf { it > 0 } ?: 180
            val paper = BackgroundRenderer.render(ctx, note, wDp, hDp)
            views.setImageViewBitmap(R.id.bg, paper.bitmap)
            views.setViewPadding(R.id.content, paper.left, paper.top, paper.right, paper.bottom)

            if (note == null) {
                // Not bound yet (or note deleted): tap to choose a note.
                val cfg = Intent(ctx, WidgetConfigActivity::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse("stickit://config/$widgetId")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                val pi = PendingIntent.getActivity(ctx, widgetId, cfg, IMMUTABLE)
                views.setViewVisibility(R.id.title_hand, View.GONE)
                views.setViewVisibility(R.id.title_marker, View.GONE)
                views.setTextViewText(R.id.title, "Stickit")
                views.setTextColor(R.id.title, BackgroundRenderer.DEFAULT_FG)
                views.setViewVisibility(R.id.title, View.VISIBLE)
                views.setViewVisibility(R.id.list, View.GONE)
                views.setViewVisibility(R.id.resize, View.GONE)
                views.setViewVisibility(R.id.empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.empty,
                    when (noteId) {
                        null -> "Tap to choose a note"
                        REPLACED -> "Moved to a resized widget.\nLong-press here and remove this one"
                        else -> "This note was deleted.\nTap to choose another"
                    },
                )
                views.setTextColor(R.id.empty, BackgroundRenderer.withAlpha(BackgroundRenderer.DEFAULT_FG, 150))
                views.setInt(R.id.edit, "setColorFilter", BackgroundRenderer.withAlpha(BackgroundRenderer.DEFAULT_FG, 170))
                views.setOnClickPendingIntent(R.id.root, pi)
                views.setOnClickPendingIntent(R.id.empty, pi)
                views.setOnClickPendingIntent(R.id.header, pi)
                mgr.updateAppWidget(widgetId, views)
                return
            }

            // Header
            val hasTitle = note.title.isNotBlank()
            val titleId = titleIdFor(note.font)
            for (id in intArrayOf(R.id.title, R.id.title_hand, R.id.title_marker)) {
                if (id != titleId) views.setViewVisibility(id, View.GONE)
            }
            views.setViewVisibility(titleId, if (hasTitle) View.VISIBLE else View.INVISIBLE)
            views.setTextViewText(titleId, TextStyler.style(note.title, note, forceBold = true))
            views.setTextColor(titleId, note.fg)
            views.setTextViewTextSize(titleId, TypedValue.COMPLEX_UNIT_SP, note.size + 2)
            views.setInt(R.id.edit, "setColorFilter", BackgroundRenderer.withAlpha(note.fg, 170))
            views.setInt(R.id.resize, "setColorFilter", BackgroundRenderer.withAlpha(note.fg, 170))
            views.setViewVisibility(R.id.resize, View.VISIBLE)
            views.setOnClickPendingIntent(
                R.id.resize,
                PendingIntent.getActivity(ctx, widgetId + 200_000, resizeIntent(ctx, note.id, widgetId), IMMUTABLE),
            )

            // Body list (scrollable, checklist items tappable)
            val svc = Intent(ctx, NoteWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            @Suppress("DEPRECATION")
            views.setRemoteAdapter(R.id.list, svc)
            views.setViewVisibility(R.id.list, View.VISIBLE)
            views.setEmptyView(R.id.list, R.id.empty)
            views.setTextViewText(R.id.empty, "Empty note — tap to write")
            views.setTextColor(R.id.empty, BackgroundRenderer.withAlpha(note.fg, 120))

            val open = PendingIntent.getActivity(ctx, widgetId, openNoteIntent(ctx, note.id), IMMUTABLE)
            views.setOnClickPendingIntent(R.id.header, open)
            views.setOnClickPendingIntent(R.id.empty, open)
            views.setOnClickPendingIntent(R.id.root, open)

            val template = if (note.checklist) {
                val toggle = Intent(ctx, NoteWidgetProvider::class.java).apply {
                    action = ACTION_TOGGLE
                    data = Uri.parse("stickit://toggle/$widgetId")
                }
                PendingIntent.getBroadcast(ctx, widgetId, toggle, MUTABLE)
            } else {
                PendingIntent.getActivity(ctx, widgetId + 100_000, openNoteIntent(ctx, note.id), MUTABLE)
            }
            views.setPendingIntentTemplate(R.id.list, template)

            mgr.updateAppWidget(widgetId, views)
        }
    }

    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(ctx, mgr, it) }
        @Suppress("DEPRECATION")
        mgr.notifyAppWidgetViewDataChanged(ids, R.id.list)
    }

    override fun onAppWidgetOptionsChanged(ctx: Context, mgr: AppWidgetManager, id: Int, newOptions: Bundle) {
        update(ctx, mgr, id) // re-render background at the new size
    }

    override fun onDeleted(ctx: Context, ids: IntArray) {
        ids.forEach { NoteRepo.unbindWidget(ctx, it) }
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            ACTION_PINNED -> {
                val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                val noteId = intent.getStringExtra(MainActivity.EXTRA_NOTE_ID)
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID && noteId != null) {
                    NoteRepo.bindWidget(ctx, widgetId, noteId)
                    val mgr = AppWidgetManager.getInstance(ctx)
                    update(ctx, mgr, widgetId)
                    // A resized copy was placed: point the old widget at it.
                    val old = intent.getIntExtra(EXTRA_REPLACES, AppWidgetManager.INVALID_APPWIDGET_ID)
                    if (old != AppWidgetManager.INVALID_APPWIDGET_ID && old != widgetId) {
                        NoteRepo.bindWidget(ctx, old, REPLACED)
                        update(ctx, mgr, old)
                    }
                    @Suppress("DEPRECATION")
                    mgr.notifyAppWidgetViewDataChanged(intArrayOf(widgetId), R.id.list)
                }
            }
            ACTION_TOGGLE -> {
                val noteId = intent.getStringExtra(MainActivity.EXTRA_NOTE_ID) ?: return
                val index = intent.getIntExtra(EXTRA_INDEX, -1)
                if (NoteRepo.toggleItem(ctx, noteId, index)) {
                    updateAll(ctx)
                    LockScreenNotifier.sync(ctx)
                    MainActivity.notifyNotesChanged()
                }
            }
            else -> super.onReceive(ctx, intent)
        }
    }
}

/** Supplies rows (checklist items or note body) to the widget's ListView. */
class NoteWidgetService : android.widget.RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        Factory(applicationContext, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, 0))

    private class Factory(val ctx: Context, val widgetId: Int) : RemoteViewsFactory {
        private var note: NoteData? = null

        override fun onCreate() {}
        override fun onDestroy() {}
        override fun onDataSetChanged() {
            note = NoteRepo.noteForWidget(ctx, widgetId)?.let { NoteRepo.find(ctx, it) }
        }

        override fun getCount(): Int {
            val n = note ?: return 0
            return when {
                n.checklist -> n.items.size
                n.body.isBlank() -> 0
                else -> 1
            }
        }

        override fun getViewAt(position: Int): RemoteViews {
            val n = note
            if (n == null) return RemoteViews(ctx.packageName, R.layout.widget_item)
            val rv = RemoteViews(ctx.packageName, NoteWidgetProvider.itemLayoutFor(n.font))
            val fill = Intent().putExtra(MainActivity.EXTRA_NOTE_ID, n.id)
            if (n.checklist && position < n.items.size) {
                val item = n.items[position]
                rv.setViewVisibility(R.id.check, View.VISIBLE)
                rv.setImageViewResource(R.id.check, if (item.done) R.drawable.ic_check_on else R.drawable.ic_check_off)
                rv.setInt(R.id.check, "setColorFilter", BackgroundRenderer.withAlpha(n.fg, if (item.done) 140 else 220))
                if (Build.VERSION.SDK_INT >= 31) {
                    rv.setViewLayoutWidth(R.id.check, n.size + 4, TypedValue.COMPLEX_UNIT_SP)
                    rv.setViewLayoutHeight(R.id.check, n.size + 4, TypedValue.COMPLEX_UNIT_SP)
                }
                rv.setTextViewText(R.id.item_text, TextStyler.style(item.text, n, strike = item.done))
                rv.setTextColor(R.id.item_text, if (item.done) BackgroundRenderer.withAlpha(n.fg, 130) else n.fg)
                fill.putExtra(NoteWidgetProvider.EXTRA_INDEX, position)
            } else {
                rv.setViewVisibility(R.id.check, View.GONE)
                rv.setTextViewText(R.id.item_text, TextStyler.style(n.body, n))
                rv.setTextColor(R.id.item_text, n.fg)
            }
            rv.setTextViewTextSize(R.id.item_text, TypedValue.COMPLEX_UNIT_SP, n.size)
            rv.setOnClickFillInIntent(R.id.row, fill)
            return rv
        }

        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount() = 3
        override fun getItemId(position: Int) = position.toLong()
        override fun hasStableIds() = false
    }
}
