package com.tntlikely.beecount

/** 快速记账·中(默认 4×2,布局 [quick_add_widget_medium])。 */
class BeeCountQuickAddMediumWidgetProvider : BeeCountQuickAddWidgetProvider() {
    override fun resolveImageKey(
        context: android.content.Context,
        appWidgetManager: android.appwidget.AppWidgetManager,
        widgetId: Int,
    ): String = "widget_quickAdd_medium"
}
