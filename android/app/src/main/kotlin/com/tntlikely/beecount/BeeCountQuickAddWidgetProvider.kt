package com.tntlikely.beecount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.io.File

/**
 * 快速记账小组件(小/中两档):分类格 → 手动记支出(预填分类);末格 → 语音记账。
 */
open class BeeCountQuickAddWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "BeeCountQuickAddWidget"
        private const val WIDTH_BREAKPOINT_SMALL_MEDIUM_DP = 260
        private const val META_SMALL = "widget_quickAdd_categoryIds_small"
        private const val META_MEDIUM = "widget_quickAdd_categoryIds_medium"

        private val CELL_IDS = intArrayOf(
            R.id.click_cell_0,
            R.id.click_cell_1,
            R.id.click_cell_2,
            R.id.click_cell_3,
            R.id.click_cell_4,
            R.id.click_cell_5,
            R.id.click_cell_6,
            R.id.click_cell_7,
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val imageKey = resolveImageKey(appWidgetManager, widgetId)
                val isSmall = imageKey == "widget_quickAdd_small"
                val metaKey = if (isSmall) META_SMALL else META_MEDIUM
                val categoryIds = parseCategoryIds(widgetData.getString(metaKey, null))
                val cellCount = if (isSmall) 4 else 8
                val categorySlots = cellCount - 1

                val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
                    bindImage(widgetData, imageKey)
                    for (i in 0 until 8) {
                        val visible = i < cellCount
                        setViewVisibility(CELL_IDS[i], if (visible) View.VISIBLE else View.GONE)
                    }
                    for (i in 0 until categorySlots) {
                        val catId = categoryIds.getOrNull(i)
                        val url = if (catId != null) {
                            "beecount://new?type=expense&category=$catId"
                        } else {
                            "beecount://new?type=expense"
                        }
                        bindClick(context, widgetId, CELL_IDS[i], url, i)
                    }
                    bindClick(
                        context,
                        widgetId,
                        CELL_IDS[categorySlots],
                        "beecount://voice",
                        100 + categorySlots,
                    )
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
        }
        setImageViewResource(R.id.widget_image, R.mipmap.ic_launcher)
    }

    private fun RemoteViews.bindClick(
        context: Context,
        widgetId: Int,
        viewId: Int,
        url: String,
        requestSuffix: Int,
    ) {
        val intent = createLaunchIntentWithDeepLink(context, url)
        val pending = PendingIntent.getActivity(
            context,
            widgetId * 100 + requestSuffix,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        setOnClickPendingIntent(viewId, pending)
    }

    private fun parseCategoryIds(raw: String?): List<Int> {
        if (raw.isNullOrBlank()) return emptyList()
        return try {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) {
                    add(arr.getInt(i))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "parseCategoryIds failed: ${e.message}")
            emptyList()
        }
    }

    private fun resolveImageKey(appWidgetManager: AppWidgetManager, widgetId: Int): String {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        if (minWidth <= 0) return "widget_quickAdd_medium"
        return if (minWidth < WIDTH_BREAKPOINT_SMALL_MEDIUM_DP) {
            "widget_quickAdd_small"
        } else {
            "widget_quickAdd_medium"
        }
    }

    private fun createLaunchIntentWithDeepLink(context: Context, url: String): Intent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                setPackage(context.packageName)
            }
        intent.data = Uri.parse(url)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return intent
    }
}
