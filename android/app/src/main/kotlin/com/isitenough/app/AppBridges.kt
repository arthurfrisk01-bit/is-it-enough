package com.isitenough.app

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 统一注册本应用的原生 MethodChannel。
 *
 * 关键点：**每个 Flutter 引擎都要注册**，包括后台 headless 引擎。
 * 早期版本只在 MainActivity 里注册，导致 App 界面不存在时
 * （进程被回收后由前台服务拉起 monitorMain）headless 引擎调用
 * `getForegroundPackage` 直接 MissingPluginException，监控静默失效、
 * 日志也写不进文件。现在 MainActivity 与 MonitorForegroundService
 * 都调用 [registerAll]。
 */
object AppBridges {

    private const val TAG = "IsItEnough/AppBridges"

    private const val DIAGNOSIS_CHANNEL = "com.isitenough.app/diagnosis"
    private const val SERVICE_CHANNEL = "com.isitenough.app/monitor_service"

    fun registerAll(engine: FlutterEngine, context: Context) {
        try {
            UsageStatsBridge(engine, context).register()
        } catch (t: Throwable) {
            Log.e(TAG, "注册 UsageStatsBridge 失败", t)
            LogStore.append(context, "注册 UsageStatsBridge 失败: ${t.message}", "Native")
        }
        try {
            LogBridge(context).register(engine)
        } catch (t: Throwable) {
            Log.e(TAG, "注册 LogBridge 失败", t)
        }
        try {
            ReminderOverlayBridge(context).register(engine)
        } catch (t: Throwable) {
            Log.e(TAG, "注册 ReminderOverlayBridge 失败", t)
            LogStore.append(context, "注册悬浮窗通道失败: ${t.message}", "Native")
        }
        try {
            registerDiagnosis(engine, context)
            registerMonitorService(engine, context)
        } catch (t: Throwable) {
            Log.e(TAG, "注册诊断/服务通道失败", t)
            LogStore.append(context, "注册诊断/服务通道失败: ${t.message}", "Native")
        }
    }

    private fun registerDiagnosis(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, DIAGNOSIS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkNotificationChannelsExist" -> {
                        val channelIds = call.argument<List<String>>("channelIds") ?: emptyList()
                        result.success(checkNotificationChannelsExist(context, channelIds))
                    }
                    // Android 14(API 34)+ 起，非通话/闹钟类应用的全屏 Intent 默认被系统降级，
                    // 需要用户在系统设置里手动开启。Dart 侧据此把强提醒降级为高优先级横幅。
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent(context))
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerMonitorService(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, SERVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        MonitorForegroundService.start(context)
                        result.success(true)
                    }
                    "stop" -> {
                        MonitorForegroundService.stop(context)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 检查指定的通知通道是否存在（Android 8+）。 */
    fun checkNotificationChannelsExist(context: Context, channelIds: List<String>): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return channelIds.all { id ->
            val exists = manager.getNotificationChannel(id) != null
            Log.d(TAG, "通道检查：$id = ${if (exists) "存在" else "不存在"}")
            exists
        }
    }

    /**
     * 探测系统是否允许本应用使用全屏 Intent。
     * 低版本或探测失败时按“可用”处理，保持原有行为。
     */
    fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        return try {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.canUseFullScreenIntent()
        } catch (t: Throwable) {
            Log.w(TAG, "canUseFullScreenIntent 探测失败，按可用处理", t)
            true
        }
    }
}
