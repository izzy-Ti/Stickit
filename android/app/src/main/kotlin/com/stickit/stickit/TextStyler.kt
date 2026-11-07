package com.stickit.stickit

import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.text.style.StyleSpan
import android.text.style.TypefaceSpan

/** Applies a note's font family / bold / italic as spans (RemoteViews-safe). */
object TextStyler {
    fun style(text: String, note: NoteData, forceBold: Boolean = false, strike: Boolean = false): CharSequence {
        if (text.isEmpty()) return text
        val s = SpannableString(text)
        val bold = note.bold || forceBold
        val tf = when {
            bold && note.italic -> Typeface.BOLD_ITALIC
            bold -> Typeface.BOLD
            note.italic -> Typeface.ITALIC
            else -> Typeface.NORMAL
        }
        if (tf != Typeface.NORMAL) s.setSpan(StyleSpan(tf), 0, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        when (note.font) {
            "serif" -> s.setSpan(TypefaceSpan("serif"), 0, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            "mono" -> s.setSpan(TypefaceSpan("monospace"), 0, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            // "hand" / "marker" are bundled fonts, set by the widget layouts.
        }
        if (strike) s.setSpan(StrikethroughSpan(), 0, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        return s
    }
}
