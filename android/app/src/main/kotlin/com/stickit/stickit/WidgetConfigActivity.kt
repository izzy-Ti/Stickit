package com.stickit.stickit

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.BaseAdapter
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.TextView

/** Lightweight native picker shown when a widget is added or reconfigured. */
class WidgetConfigActivity : Activity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics,
    ).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        widgetId = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) { finish(); return }

        val notes = NoteRepo.all(this).sortedByDescending { it.updated }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(24), dp(20), 0)
        }
        content.addView(TextView(this).apply {
            text = "Pick a note"
            setTextColor(0xFFF2EEFA.toInt())
            textSize = 26f
            typeface = Typeface.DEFAULT_BOLD
        })
        content.addView(TextView(this).apply {
            text = "It will stay on your screen and update as you edit it."
            setTextColor(0xFF8E87A0.toInt())
            textSize = 14f
            setPadding(0, dp(4), 0, dp(18))
        })

        val list = ListView(this).apply {
            divider = ColorDrawable(Color.TRANSPARENT)
            dividerHeight = dp(10)
            selector = ColorDrawable(Color.TRANSPARENT)
            clipToPadding = false
            setPadding(0, 0, 0, dp(24))
            adapter = Adapter(notes)
            setOnItemClickListener { _, _, pos, _ ->
                if (pos == 0) {
                    val id = NoteRepo.createBlank(this@WidgetConfigActivity)
                    MainActivity.notifyNotesChanged()
                    bindAndFinish(id)
                    startActivity(NoteWidgetProvider.openNoteIntent(this@WidgetConfigActivity, id))
                } else {
                    bindAndFinish(notes[pos - 1].id)
                }
            }
        }
        content.addView(list, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))

        val root = FrameLayout(this).apply {
            setBackgroundColor(0xFF0A0A0D.toInt())
            fitsSystemWindows = true
            addView(content)
        }
        setContentView(root)
    }

    private fun bindAndFinish(noteId: String) {
        NoteRepo.bindWidget(this, widgetId, noteId)
        val mgr = AppWidgetManager.getInstance(this)
        NoteWidgetProvider.update(this, mgr, widgetId)
        @Suppress("DEPRECATION")
        mgr.notifyAppWidgetViewDataChanged(intArrayOf(widgetId), R.id.list)
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        finish()
    }

    private inner class Adapter(val notes: List<NoteData>) : BaseAdapter() {
        override fun getCount() = notes.size + 1
        override fun getItem(position: Int): Any? = if (position == 0) null else notes[position - 1]
        override fun getItemId(position: Int) = position.toLong()

        override fun getView(position: Int, convertView: View?, parent: ViewGroup?): View {
            val tv = (convertView as? TextView) ?: TextView(this@WidgetConfigActivity).apply {
                setPadding(dp(18), dp(16), dp(18), dp(16))
                maxLines = 3
                ellipsize = TextUtils.TruncateAt.END
                textSize = 16f
                gravity = Gravity.CENTER_VERTICAL
            }
            val bg = GradientDrawable().apply { cornerRadius = dp(18).toFloat() }
            if (position == 0) {
                tv.text = "＋  New note"
                tv.typeface = Typeface.DEFAULT_BOLD
                tv.setTextColor(Color.WHITE)
                bg.setColor(0xFF6C3BEA.toInt())
            } else {
                val n = notes[position - 1]
                val preview = n.plainText().lineSequence().firstOrNull { it.isNotBlank() }.orEmpty()
                val label = when {
                    n.title.isNotBlank() && preview.isNotBlank() -> "${n.title}\n$preview"
                    n.title.isNotBlank() -> n.title
                    preview.isNotBlank() -> preview
                    else -> "Empty note"
                }
                tv.text = TextStyler.style(label, n)
                tv.typeface = Typeface.DEFAULT
                tv.setTextColor(n.fg)
                bg.setColor(n.bg)
            }
            tv.background = bg
            return tv
        }
    }
}
