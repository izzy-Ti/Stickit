package com.stickit.stickit

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

data class NoteItem(val text: String, val done: Boolean)

data class NoteData(
    val id: String,
    val title: String,
    val body: String,
    val checklist: Boolean,
    val items: List<NoteItem>,
    val bg: Int,
    val fg: Int,
    val style: String,
    val opacity: Float,
    val size: Float,
    val font: String,
    val bold: Boolean,
    val italic: Boolean,
    val lock: Boolean,
    val updated: Long,
) {
    /** Plain-text rendering (used for lock-screen notifications). */
    fun plainText(): String =
        if (checklist) items.joinToString("\n") { (if (it.done) "✓  " else "○  ") + it.text }
        else body

    companion object {
        /** Older, more saturated presets mapped to their softer replacements. */
        private val LEGACY = listOf(
            0xFFFFF59D, 0xFFFFF6C7, 0xFFFFCC80, 0xFFFFE2BF, 0xFFFFAB91, 0xFFFFD3C6,
            0xFFF48FB1, 0xFFFBD0DF, 0xFFCE93D8, 0xFFE8D0EE, 0xFFB39DDB, 0xFFDCD3F2,
            0xFF90CAF9, 0xFFCFE6FB, 0xFF80DEEA, 0xFFCCF0F3, 0xFFA5D6A7, 0xFFD5ECD3,
            0xFFE6EE9C, 0xFFEEF4C6,
        ).let { flat -> flat.chunked(2).associate { (a, b) -> a.toInt() to b.toInt() } }

        private fun soften(c: Int) = LEGACY[c] ?: c

        fun from(o: JSONObject): NoteData {
            val arr = o.optJSONArray("items") ?: JSONArray()
            val items = (0 until arr.length()).map {
                val i = arr.getJSONObject(it)
                NoteItem(i.optString("t"), i.optBoolean("d"))
            }
            return NoteData(
                id = o.getString("id"),
                title = o.optString("title"),
                body = o.optString("body"),
                checklist = o.optBoolean("checklist"),
                items = items,
                bg = soften(o.optLong("bg", 0xFFFFF6C7L).toInt()),
                fg = o.optLong("fg", 0xFF1A1A1AL).toInt(),
                style = o.optString("style", "solid"),
                opacity = o.optDouble("opacity", 1.0).toFloat(),
                size = o.optDouble("size", 16.0).toFloat(),
                font = o.optString("font", "sans"),
                bold = o.optBoolean("bold"),
                italic = o.optBoolean("italic"),
                lock = o.optBoolean("lock"),
                updated = o.optLong("updated"),
            )
        }
    }
}

/**
 * Offline note storage shared by the Flutter UI, the widgets and the
 * lock-screen notifications. The Flutter side owns the JSON schema.
 */
object NoteRepo {
    private const val PREFS = "stickit_notes"
    private const val KEY_NOTES = "notes"
    private const val WIDGET_PREFIX = "w_"

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun raw(ctx: Context): String = prefs(ctx).getString(KEY_NOTES, "[]") ?: "[]"

    fun saveRaw(ctx: Context, json: String) {
        prefs(ctx).edit().putString(KEY_NOTES, json).apply()
    }

    private fun array(ctx: Context): JSONArray =
        try { JSONArray(raw(ctx)) } catch (_: Exception) { JSONArray() }

    fun all(ctx: Context): List<NoteData> {
        val arr = array(ctx)
        return (0 until arr.length()).mapNotNull {
            try { NoteData.from(arr.getJSONObject(it)) } catch (_: Exception) { null }
        }
    }

    fun find(ctx: Context, id: String): NoteData? = all(ctx).firstOrNull { it.id == id }

    /** Toggles a checklist item straight from a widget tap. */
    fun toggleItem(ctx: Context, noteId: String, index: Int): Boolean {
        val arr = array(ctx)
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optString("id") != noteId) continue
            val items = o.optJSONArray("items") ?: return false
            if (index !in 0 until items.length()) return false
            val item = items.getJSONObject(index)
            item.put("d", !item.optBoolean("d"))
            o.put("updated", System.currentTimeMillis())
            saveRaw(ctx, arr.toString())
            return true
        }
        return false
    }

    /** Creates an empty note (used when adding a widget for a brand-new note). */
    fun createBlank(ctx: Context): String {
        val id = java.lang.Long.toString(System.currentTimeMillis(), 36) +
            Integer.toString((Math.random() * 1_000_000).toInt(), 36)
        val o = JSONObject()
            .put("id", id).put("title", "").put("body", "")
            .put("checklist", false).put("items", JSONArray())
            .put("bg", 0xFFFFF6C7L).put("fg", 0xFF1A1A1AL)
            .put("style", "solid").put("opacity", 1.0).put("size", 16.0)
            .put("font", "sans").put("bold", false).put("italic", false)
            .put("pinned", false).put("lock", false)
            .put("updated", System.currentTimeMillis())
        val arr = array(ctx).put(o)
        prefs(ctx).edit().putString(KEY_NOTES, arr.toString()).commit()
        return id
    }

    // ---- widget ↔ note bindings ----

    fun bindWidget(ctx: Context, widgetId: Int, noteId: String) {
        prefs(ctx).edit().putString(WIDGET_PREFIX + widgetId, noteId).commit()
    }

    fun unbindWidget(ctx: Context, widgetId: Int) {
        prefs(ctx).edit().remove(WIDGET_PREFIX + widgetId).apply()
    }

    fun noteForWidget(ctx: Context, widgetId: Int): String? =
        prefs(ctx).getString(WIDGET_PREFIX + widgetId, null)

    fun widgetCount(ctx: Context, noteId: String): Int =
        prefs(ctx).all.count { (k, v) -> k.startsWith(WIDGET_PREFIX) && v == noteId }
}
