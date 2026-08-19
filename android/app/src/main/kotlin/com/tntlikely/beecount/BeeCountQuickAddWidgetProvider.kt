package com.tntlikely.beecount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 快速记账小组件:小档 2×2、中档 4×1(占 4×2 槽位),四入口深链固定。
 */
open class BeeCountQuickAddWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "BeeCountQuickAddWidget"
        private const val IMAGE_KEY_SMALL = "widget_quickAdd_small"
        private const val IMAGE_KEY_MEDIUM = "widget_quickAdd_medium"

        /** 语音 / AI / 拍照 / 记一笔 —— 小 2×2 与中 1×4 顺序一致。 */
        private val ACTION_URLS = arrayOf(
            "beecount://voice",
            "beecount://ai-chat",
            "beecount://camera",
            "beecount://new?type=expense",
        )

        private val CELL_IDS = intArrayOf(
            R.id.click_cell_0,
            R.id.click_cell_1,
            R.id.click_cell_2,
            R.id.click_cell_3,
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val imageKey = resolveImageKey(context, appWidgetManager, widgetId)
                val layoutId = if (imageKey == IMAGE_KEY_SMALL) {
                    R.layout.quick_add_widget
                } else {
                    R.layout.quick_add_widget_medium
                }
                val views = RemoteViews(context.packageName, layoutId).apply {
                    bindImage(widgetData, imageKey)
                    for (i in CELL_IDS.indices) {
                        bindClick(context, widgetId, CELL_IDS[i], ACTION_URLS[i], i)
                    }
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update widget $widgetId", e)
            }
        }
    }

    private fun RemoteViews.bindImage(widgetData: SharedPreferences, imageKey: String) {
        val imagePath = widgetData.getString(imageKey, null)
        if (imagePath != null) {
            val bitmap = BitmapFactory.decodeFile(imagePath)
            if (bitmap != null) {
                setImageViewBitmap(R.id.widget_image, bitmap)
                return
            }
            Log.w(TAG, "Failed to decode bitmap for key $imageKey path=$imagePath")
        } else {
            Log.w(TAG, "No image path for key $imageKey")
        }
        setImageViewResource(
            R.id.widget_image,
            if (imageKey == IMAGE_KEY_MEDIUM) R.drawable.widget_preview_quickadd_medium
            else R.drawable.widget_preview_quickadd,
        )
    }

    private fun RemoteViews.bindClick(
        context: Context,
        widgetId: Int,
        viewId: Int,
        url: String,
        requestSuffix: Int,
    ) {
        val intent = WidgetDeepLinkHelper.launchIntent(context, url)
        val pending = PendingIntent.getActivity(
            context,
            widgetId * 10 + requestSuffix,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        setOnClickPendingIntent(viewId, pending)
    }

    /** 中号入口 provider 固定 medium;父类 provider 在宽度不足 medium 阈值时用 small。 */
    protected open fun resolveImageKey(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ): String {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        if (minWidth in 1..169) return IMAGE_KEY_SMALL
        return IMAGE_KEY_MEDIUM
    }
}
