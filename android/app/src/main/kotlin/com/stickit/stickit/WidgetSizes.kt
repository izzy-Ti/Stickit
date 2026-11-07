package com.stickit.stickit

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context

/*
 * Android launchers decide how many cells a widget takes, and some can't resize
 * widgets at all. So the same note widget is registered once per size; the app's
 * resize screen pins whichever one matches the size the user dragged to.
 */
class NoteWidget2x1 : NoteWidgetProvider()
class NoteWidget3x1 : NoteWidgetProvider()
class NoteWidget4x1 : NoteWidgetProvider()
class NoteWidget3x2 : NoteWidgetProvider()
class NoteWidget4x2 : NoteWidgetProvider()
class NoteWidget2x3 : NoteWidgetProvider()
class NoteWidget3x3 : NoteWidgetProvider()
class NoteWidget4x3 : NoteWidgetProvider()
class NoteWidget2x4 : NoteWidgetProvider()
class NoteWidget3x4 : NoteWidgetProvider()
class NoteWidget4x4 : NoteWidgetProvider()

object WidgetSizes {
    const val MIN_W = 2
    const val MAX_W = 4
    const val MIN_H = 1
    const val MAX_H = 4

    private val all: List<Triple<Int, Int, Class<out AppWidgetProvider>>> = listOf(
        Triple(2, 2, NoteWidgetProvider::class.java),
        Triple(2, 1, NoteWidget2x1::class.java),
        Triple(3, 1, NoteWidget3x1::class.java),
        Triple(4, 1, NoteWidget4x1::class.java),
        Triple(3, 2, NoteWidget3x2::class.java),
        Triple(4, 2, NoteWidget4x2::class.java),
        Triple(2, 3, NoteWidget2x3::class.java),
        Triple(3, 3, NoteWidget3x3::class.java),
        Triple(4, 3, NoteWidget4x3::class.java),
        Triple(2, 4, NoteWidget2x4::class.java),
        Triple(3, 4, NoteWidget3x4::class.java),
        Triple(4, 4, NoteWidget4x4::class.java),
    )

    fun providerFor(w: Int, h: Int): Class<out AppWidgetProvider> =
        all.firstOrNull { it.first == w && it.second == h }?.third ?: NoteWidgetProvider::class.java

    /** Cell size of a placed widget, from the provider it was added with. */
    fun sizeOf(mgr: AppWidgetManager, widgetId: Int): Pair<Int, Int> {
        val cls = mgr.getAppWidgetInfo(widgetId)?.provider?.className
        val match = all.firstOrNull { it.third.name == cls }
        return if (match != null) match.first to match.second else 2 to 2
    }

    fun allWidgetIds(ctx: Context): IntArray {
        val mgr = AppWidgetManager.getInstance(ctx)
        return all.flatMap { mgr.getAppWidgetIds(ComponentName(ctx, it.third)).asList() }.toIntArray()
    }
}
