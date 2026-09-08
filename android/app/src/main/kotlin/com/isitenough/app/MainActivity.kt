package com.isitenough.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "IsItEnough/MainActivity"
        private const val STRONG_CHANNEL_ID = "reminder_strong"
        private const val WEAK_CHANNEL_ID = "reminder_soft"
        private const val DIAGNOSIS_CHANNEL = "com.isitenough.app/diagnosis"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册 UsageStatsManager 的 MethodChannel。
        UsageStatsBridge(flutterEngine, this).register()

        // 注册诊断 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DIAGNOSIS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNotificationChannelsExist" -> {
                    val channelIds = call.argument<List<String>>("channelIds") ?: emptyList()
                    val exist = checkNotificationChannelsExist(channelIds)
                    result.success(exist)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 在原生层显式创建通知通道（Android 8+）。
     * flutter_local_notifications 的自动创建在部分 ROM 上不可靠，
     * 此处确保两个通道在应用启动时就存在。
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            Log.d(TAG, "Android 8 以下无需创建 NotificationChannel")
            return
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 强提醒通道：全屏打断 + 高优先级
        val strongChannel = NotificationChannel(
            STRONG_CHANNEL_ID,
            "强提醒（全屏打断）",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "全屏打断提醒，点亮屏幕，用于紧急数字健康提醒"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 200, 500)
            enableLights(true)
            lightColor = 0xFF9ED8C4.toInt()
            setShowBadge(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }

        // 弱提醒通道：轻量横幅 + 高优先级（不全屏）
        val weakChannel = NotificationChannel(
            WEAK_CHANNEL_ID,
            "弱提醒（轻量提示）",
            NotificationManager.IMPORTANCE_HIGH  // 仍用 HIGH 确保横幅显示
        ).apply {
            description = "轻提醒横幅，不打断操作，温和提示"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 200, 100, 200)
            enableLights(true)
            lightColor = 0xFF9ED8C4.toInt()
            setShowBadge(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }

        notificationManager.createNotificationChannel(strongChannel)
        notificationManager.createNotificationChannel(weakChannel)

        Log.i(TAG, "通知通道已在原生层创建：强提醒($STRONG_CHANNEL_ID)、弱提醒($WEAK_CHANNEL_ID)")
    }

    /**
     * 检查指定的通知通道是否存在（Android 8+）。
     * 用于诊断工具验证通道创建是否成功。
     */
    private fun checkNotificationChannelsExist(channelIds: List<String>): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            // Android 8 以下无 NotificationChannel 概念，总是返回 true
            return true
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        return channelIds.all { channelId ->
            val channel = notificationManager.getNotificationChannel(channelId)
            val exists = channel != null
            Log.d(TAG, "通道检查：$channelId = ${if (exists) "存在" else "不存在"}")
            exists
        }
    }
}
