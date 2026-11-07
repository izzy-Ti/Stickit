package com.stickit.stickit

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import kotlin.math.min
import kotlin.math.sqrt

/** Draws a note's background (colour, pattern, opacity, rounded corners) for widgets. */
object BackgroundRenderer {
    private const val MAX_PIXELS = 360_000f

    fun render(ctx: Context, note: NoteData?, widthDp: Int, heightDp: Int): Bitmap {
        val d = ctx.resources.displayMetrics.density
        var w = widthDp * d
        var h = heightDp * d
        val scale = min(1f, sqrt(MAX_PIXELS / (w * h)))
        w *= scale; h *= scale
        val px = d * scale
        val bmp = Bitmap.createBitmap(w.toInt().coerceAtLeast(1), h.toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val rect = RectF(0f, 0f, bmp.width.toFloat(), bmp.height.toFloat())
        val radius = 22 * px
        c.clipPath(Path().apply { addRoundRect(rect, radius, radius, Path.Direction.CW) })

        val bg = note?.bg ?: 0xFF1E1B26.toInt()
        val fg = note?.fg ?: Color.WHITE
        val alpha = ((note?.opacity ?: 1f).coerceIn(0f, 1f) * 255).toInt()
        val style = note?.style ?: "solid"

        val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        val base = withAlpha(bg, alpha)
        if (style == "gradient") {
            val end = withAlpha(darken(bg, 0.28f), alpha)
            fill.shader = LinearGradient(0f, 0f, rect.right, rect.bottom, base, end, Shader.TileMode.CLAMP)
        } else {
            fill.color = base
        }
        c.drawRect(rect, fill)

        val spacing = 24 * px
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(fg, (0.13f * 255).toInt())
            strokeWidth = px
        }
        when (style) {
            "lined" -> {
                var y = spacing * 1.6f
                while (y < rect.bottom) { c.drawLine(0f, y, rect.right, y, line); y += spacing }
            }
            "grid" -> {
                val s = spacing * 0.8f
                var y = s
                while (y < rect.bottom) { c.drawLine(0f, y, rect.right, y, line); y += s }
                var x = s
                while (x < rect.right) { c.drawLine(x, 0f, x, rect.bottom, line); x += s }
            }
            "dots" -> {
                val s = spacing * 0.7f
                line.color = withAlpha(fg, (0.2f * 255).toInt())
                var y = s / 2
                while (y < rect.bottom) {
                    var x = s / 2
                    while (x < rect.right) { c.drawCircle(x, y, 1.4f * px, line); x += s }
                    y += s
                }
            }
        }
        return bmp
    }

    fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))

    private fun darken(color: Int, t: Float): Int = Color.rgb(
        (Color.red(color) * (1 - t)).toInt(),
        (Color.green(color) * (1 - t)).toInt(),
        (Color.blue(color) * (1 - t)).toInt(),
    )
}
