package com.isitenough.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "IsItEnough/MainActivity"
        private const val STRONG_CHANNEL_ID = "reminder_strong"
        private const val WEAK_CHANNEL_ID = "reminder_soft"
        private const val SILENT_CHANNEL_ID = "reminder_silent"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // 界面已创建：销毁后台 headless 引擎，由界面引擎接管监控，
        // 避免两个引擎同时轮询造成重复提醒。
        MonitorForegroundService.releaseHeadlessEngine(this)
        MonitorForegroundService.uiAlive = true
        super.onCreate(savedInstanceState)
        createNotificationChannels()
        LogStore.append(this, "MainActivity.onCreate，界面引擎接管监控", "Native")
    }

    override fun onDestroy() {
        // Activity 销毁不代表进程结束；这里保守置为 false，
        // 服务在下次 onStartCommand 时再决定是否拉起 headless 引擎。
        MonitorForegroundService.uiAlive = false
        LogStore.append(this, "MainActivity.onDestroy，界面退出", "Native")
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 界面引擎注册全部原生通道（使用情况访问 / 诊断 / 保活服务 / 日志）。
        AppBridges.registerAll(flutterEngine, this)
    }

    /**
     * 在原生层显式创建通知通道（Android 8+）。
     * flutter_local_notifications 的自动创建在部分 ROM 上不可靠，
     * 此处确保通道在应用启动时就存在。
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

        // 静默留存通道：悬浮窗已展示时使用，只留记录不打扰
        val silentChannel = NotificationChannel(
            SILENT_CHANNEL_ID,
            "提醒留存（静默）",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "悬浮窗已展示时仅留一条静默记录，不响铃、不震动"
            enableVibration(false)
            setSound(null, null)
            enableLights(false)
            setShowBadge(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }

        notificationManager.createNotificationChannel(strongChannel)
        notificationManager.createNotificationChannel(weakChannel)
        notificationManager.createNotificationChannel(silentChannel)

        Log.i(
            TAG,
            "通知通道已在原生层创建：$STRONG_CHANNEL_ID / $WEAK_CHANNEL_ID / $SILENT_CHANNEL_ID"
        )
        LogStore.append(
            this,
            "通知通道已创建：$STRONG_CHANNEL_ID / $WEAK_CHANNEL_ID / $SILENT_CHANNEL_ID" +
                "，通知总开关=${notificationManager.areNotificationsEnabled()}",
            "Native",
        )
    }
}
