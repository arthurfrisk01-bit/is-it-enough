package com.isitenough.app

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * UsageStatsManager MethodChannel 桥。
 *
 * 提供三个能力：
 * 1. isUsageAccessGranted    —— 当前是否已授予“使用情况访问权限”
 * 2. openUsageAccessSettings —— 跳转系统使用情况访问设置页
 * 3. getForegroundPackage    —— 通过 UsageStatsManager 推断当前前台应用包名
 */
class UsageStatsBridge(
    engine: FlutterEngine,
    private val context: Context,
) : MethodCallHandler {

    companion object {
        private const val CHANNEL = "com.isitenough.app/usage_stats"
        private const val LOOKBACK_WINDOW_MS = 2 * 60 * 1000L // 2 分钟（聚合法回退窗口）
        private const val EVENT_LOOKBACK_MS = 60 * 60 * 1000L // 事件法查询窗口：1 小时
    }

    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        CHANNEL,
    )

    fun register() {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isUsageAccessGranted" -> result.success(isUsageAccessGranted())
            "openUsageAccessSettings" -> openUsageAccessSettings(result)
            "getForegroundPackage" -> getForegroundPackage(result)
            "getAppLabel" -> getAppLabel(call, result)
            else -> result.notImplemented()
        }
    }

    /** 检查“使用情况访问权限”是否已授予。 */
    private fun isUsageAccessGranted(): Boolean {
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (_: Exception) {
            false
        }
    }

    /** 打开系统“使用情况访问权限”设置页。 */
    private fun openUsageAccessSettings(result: Result) {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_USAGE_SETTINGS_FAILED", e.message, e.stackTraceToString())
        }
    }

    /**
     * 返回当前最可能位于前台的包名。
     *
     * 两段式推断：
     * 1. 事件法（首选）：扫描 usage events，取“最近一次 ACTIVITY_RESUMED 且其后
     *    没有 PAUSED/STOPPED”的包。这是真实的前台切换记录，不会像“取
     *    lastTimeUsed 最大”那样被 MIUI 桌面/最近任务(com.miui.home)的短暂覆盖
     *    带偏 —— 用户明明在刷微信却被判定成桌面，正是旧启发式的典型误判。
     * 2. 聚合法（回退）：部分 ROM 不返回 events 时退回旧逻辑。
     */
    private fun getForegroundPackage(result: Result) {
        try {
            if (!isUsageAccessGranted()) {
                result.success(null)
                return
            }

            val usageStatsManager =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()

            val eventForeground = inferForegroundFromEvents(
                usageStatsManager,
                now - EVENT_LOOKBACK_MS,
                now,
            )
            if (eventForeground != null) {
                result.success(eventForeground)
                return
            }

            val begin = now - LOOKBACK_WINDOW_MS
            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                begin,
                now,
            )

            val foregroundPackage = stats
                ?.filter { it.lastTimeUsed > 0 && it.packageName != context.packageName }
                ?.maxByOrNull { it.lastTimeUsed }
                ?.packageName

            result.success(foregroundPackage)
        } catch (e: SecurityException) {
            result.error(
                "USAGE_ACCESS_REQUIRED",
                "缺少使用情况访问权限：${e.message}",
                e.stackTraceToString(),
            )
        } catch (e: Exception) {
            result.error("GET_FOREGROUND_FAILED", e.message, e.stackTraceToString())
        }
    }

    /**
     * 事件法推断前台包名。
     *
     * 规则：最近一个 RESUME 的包为前台；该包出现 PAUSED/STOPPED 后视为离开
     * （期间有新的 RESUME 则换人）。返回 null 表示窗口内无有效事件（例如用户
     * 长时间停留在某应用、窗口内只有一次很早的 RESUME），由调用方回退聚合法。
     */
    private fun inferForegroundFromEvents(
        usageStatsManager: UsageStatsManager,
        begin: Long,
        end: Long,
    ): String? {
        val events = usageStatsManager.queryEvents(begin, end)
        val event = android.app.usage.UsageEvents.Event()
        var current: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            when (event.eventType) {
                android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED -> current = pkg
                android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED,
                android.app.usage.UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (pkg == current) current = null
                }
            }
        }
        return current
    }

    /** 获取应用名称（通过包名查询 ApplicationInfo）。 */
    private fun getAppLabel(call: MethodCall, result: Result) {
        try {
            val packageName = call.argument<String>("packageName")
            if (packageName.isNullOrEmpty()) {
                result.error("INVALID_ARGUMENT", "packageName is required", null)
                return
            }

            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            val label = pm.getApplicationLabel(appInfo).toString()
            result.success(label)
        } catch (e: android.content.pm.PackageManager.NameNotFoundException) {
            result.success(null)  // 应用未安装，返回null
        } catch (e: Exception) {
            result.error("GET_APP_LABEL_FAILED", e.message, e.stackTraceToString())
        }
    }
}
