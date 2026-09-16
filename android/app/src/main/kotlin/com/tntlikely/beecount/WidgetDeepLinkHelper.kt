package com.tntlikely.beecount

import android.content.Context
import android.content.Intent
import android.net.Uri

/** 小组件点击启动 App 并携带 beecount:// 深链(MIUI 等机型用 ACTION_VIEW 更稳)。 */
object WidgetDeepLinkHelper {
    fun launchIntent(context: Context, url: String): Intent {
        return Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            setPackage(context.packageName)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
        }
    }
}
