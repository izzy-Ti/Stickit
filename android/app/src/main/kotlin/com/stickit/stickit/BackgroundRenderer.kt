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
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Draws a note as a real sticky note for widgets: a slightly tilted paper square with a soft
 * drop shadow, a strip of tape on top and a folded bottom-right corner.
 */
object BackgroundRenderer {
    private const val MAX_PIXELS = 360_000f

    /** Space around the paper for the shadow and tape (dp). */
    private const val EDGE_DP = 9f

    /** Inner text padding on the paper (dp). */
    private const val PAD_X_DP = 14f
    private const val PAD_TOP_DP = 16f
    private const val PAD_BOTTOM_DP = 14f

    const val DEFAULT_BG = 0xFFFFF6C7.toInt()
    const val DEFAULT_FG = 0xFF1A1A1A.toInt()

    /** Rendered background plus the padding (in px) that keeps content inside the paper. */
    class Result(val bitmap: Bitmap, val left: Int, val top: Int, val right: Int, val bottom: Int)

    private val TILTS = floatArrayOf(-2.4f, 1.8f, -1.6f, 2.6f, -2.0f, 1.4f)

    /** A stable, per-note tilt so each note leans its own way. */
    fun tiltFor(note: NoteData?): Float =
        TILTS[abs((note?.id ?: "").hashCode() % TILTS.size)]

    fun render(ctx: Context, note: NoteData?, widthDp: Int, heightDp: Int): Result {
        val density = ctx.resources.displayMetrics.density
        val wDp = widthDp.toFloat()
        val hDp = heightDp.toFloat()

        // --- Geometry in dp: biggest paper whose rotated bounds fit inside the widget. ---
        val angle = tiltFor(note)
        val rad = Math.toRadians(abs(angle).toDouble())
        val cs = cos(rad).toFloat()
        val sn = sin(rad).toFloat()
        val aw = wDp - 2 * EDGE_DP
        val ah = hDp - 2 * EDGE_DP
        val det = cs * cs - sn * sn
        val pw = ((aw * cs - ah * sn) / det).coerceAtLeast(aw * 0.8f)
        val ph = ((ah * cs - aw * sn) / det).coerceAtLeast(ah * 0.8f)

        // Axis-aligned area that stays on the paper despite the tilt (conservative).
        val innerHalfW = pw / 2 - (ph / 2) * sn
        val innerHalfH = ph / 2 - (pw / 2) * sn
        val padX = wDp / 2 - innerHalfW + PAD_X_DP
        val padTop = hDp / 2 - innerHalfH + PAD_TOP_DP
        val padBottom = hDp / 2 - innerHalfH + PAD_BOTTOM_DP

        // --- Bitmap ---
        var wPx = wDp * density
        var hPx = hDp * density
        val scale = min(1f, sqrt(MAX_PIXELS / (wPx * hPx)))
        wPx *= scale; hPx *= scale
        val px = density * scale // bitmap pixels per dp
        val bmp = Bitmap.createBitmap(wPx.toInt().coerceAtLeast(1), hPx.toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)

        val bg = note?.bg ?: DEFAULT_BG
        val fg = note?.fg ?: DEFAULT_FG
        val opacity = (note?.opacity ?: 1f).coerceIn(0f, 1f)
        val alpha = (opacity * 255).toInt()
        val style = note?.style ?: "solid"

        c.translate(bmp.width / 2f, bmp.height / 2f)
        c.rotate(angle)

        val l = -pw / 2 * px
        val t = -ph / 2 * px
        val r = pw / 2 * px
        val b = ph / 2 * px
        val fold = min(pw, ph) * 0.13f * px
        val corner = 2.5f * px

        // Paper outline with the bottom-right corner folded away.
        val paper = Path().apply {
            moveTo(l + corner, t)
            lineTo(r - corner, t)
            quadTo(r, t, r, t + corner)
            lineTo(r, b - fold)
            lineTo(r - fold, b)
            lineTo(l + corner, b)
            quadTo(l, b, l, b - corner)
            lineTo(l, t + corner)
            quadTo(l, t, l + corner, t)
            close()
        }

        // Soft shadow, slightly heavier at the bottom like a lifted note.
        val shadow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(bg, alpha)
            setShadowLayer(6f * px, 0f, 3.5f * px, Color.argb((70 * opacity).toInt(), 0, 0, 0))
        }
        c.drawPath(paper, shadow)

        // Paper fill.
        val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        if (style == "gradient") {
            fill.shader = LinearGradient(l, t, r, b, withAlpha(bg, alpha), withAlpha(darken(bg, 0.18f), alpha), Shader.TileMode.CLAMP)
        } else {
            fill.color = withAlpha(bg, alpha)
        }
        c.drawPath(paper, fill)

        c.save()
        c.clipPath(paper)

        // Gentle light falloff so it reads as paper rather than a flat rectangle.
        val sheen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f, t, 0f, b,
                intArrayOf(Color.argb((40 * opacity).toInt(), 255, 255, 255), Color.TRANSPARENT, Color.argb((22 * opacity).toInt(), 0, 0, 0)),
                floatArrayOf(0f, 0.45f, 1f),
                Shader.TileMode.CLAMP,
            )
        }
        c.drawRect(l, t, r, b, sheen)

        // Patterns.
        val spacing = 24 * px
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(fg, (0.13f * 255).toInt())
            strokeWidth = px
        }
        when (style) {
            "lined" -> {
                var y = t + spacing * 1.6f
                while (y < b) { c.drawLine(l, y, r, y, line); y += spacing }
            }
            "grid" -> {
                val s = spacing * 0.8f
                var y = t + s
                while (y < b) { c.drawLine(l, y, r, y, line); y += s }
                var x = l + s
                while (x < r) { c.drawLine(x, t, x, b, line); x += s }
            }
            "dots" -> {
                val s = spacing * 0.7f
                line.color = withAlpha(fg, (0.2f * 255).toInt())
                var y = t + s / 2
                while (y < b) {
                    var x = l + s / 2
                    while (x < r) { c.drawCircle(x, y, 1.4f * px, line); x += s }
                    y += s
                }
            }
        }
        c.restore()

        // Folded corner flap.
        val flap = Path().apply {
            moveTo(r, b - fold)
            lineTo(r - fold, b)
            lineTo(r - fold * 0.92f, b - fold * 0.92f)
            close()
        }
        val flapPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                r - fold, b - fold, r - fold / 2, b - fold / 2,
                withAlpha(darken(bg, 0.10f), alpha), withAlpha(darken(bg, 0.22f), alpha),
                Shader.TileMode.CLAMP,
            )
            setShadowLayer(2.5f * px, -1f * px, -1f * px, Color.argb((45 * opacity).toInt(), 0, 0, 0))
        }
        c.drawPath(flap, flapPaint)

        // Strip of translucent tape across the top edge.
        c.save()
        c.translate(0f, t)
        c.rotate(-angle * 1.4f)
        val tapeW = (pw * 0.36f).coerceIn(36f, 90f) * px
        val tapeH = 13f * px
        val tape = RectF(-tapeW / 2, -tapeH / 2, tapeW / 2, tapeH / 2)
        val tapePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(150, 255, 255, 255)
            setShadowLayer(1.5f * px, 0f, 0.8f * px, Color.argb(35, 0, 0, 0))
        }
        c.drawRect(tape, tapePaint)
        val tapeEdge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(40, 0, 0, 0)
            this.style = Paint.Style.STROKE
            strokeWidth = 0.6f * px
        }
        c.drawRect(tape, tapeEdge)
        c.restore()

        val toPx = { dp: Float -> (dp * density).toInt() }
        return Result(bmp, toPx(padX), toPx(padTop), toPx(padX), toPx(padBottom))
    }

    fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))

    private fun darken(color: Int, t: Float): Int = Color.rgb(
        (Color.red(color) * (1 - t)).toInt(),
        (Color.green(color) * (1 - t)).toInt(),
        (Color.blue(color) * (1 - t)).toInt(),
    )
}
