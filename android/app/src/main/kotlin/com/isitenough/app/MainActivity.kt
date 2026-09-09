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
        private const val SILENT_CHANNEL_ID = "reminder_silent"
        private const val DIAGNOSIS_CHANNEL = "com.isitenough.app/diagnosis"
        private const val SERVICE_CHANNEL = "com.isitenough.app/monitor_service"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // 界面已创建：销毁后台 headless 引擎，由界面引擎接管监控，
        // 避免两个引擎同时轮询造成重复提醒。
        MonitorForegroundService.releaseHeadlessEngine()
        MonitorForegroundService.uiAlive = true
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun onDestroy() {
        // Activity 销毁不代表进程结束；这里保守置为 false，
        // 服务在下次 onStartCommand 时再决定是否拉起 headless 引擎。
        MonitorForegroundService.uiAlive = false
        super.onDestroy()
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
                // Android 14(API 34)+ 起，非通话/闹钟类应用的全屏 Intent 默认被系统降级，
                // 需要用户在系统设置里手动开启。Dart 侧据此把强提醒降级为高优先级横幅，
                // 避免用户误以为强提醒失效。
                "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
                else -> result.notImplemented()
            }
        }

        // 后台保活服务启停控制（由 Dart 侧按“后台监控”开关调用）
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    MonitorForegroundService.start(this)
                    result.success(true)
                }
                "stop" -> {
                    MonitorForegroundService.stop(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
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

    /**
     * 探测系统是否允许本应用使用全屏 Intent。
     *
     * Android 14(API 34) 起默认只对通话/闹钟类应用开放，其余需用户手动授权；
     * 低版本或探测失败时按“可用”处理，保持原有行为。
     */
    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        return try {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.canUseFullScreenIntent()
        } catch (t: Throwable) {
            Log.w(TAG, "canUseFullScreenIntent 探测失败，按可用处理", t)
            true
        }
    }
}
