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
        private const val LOOKBACK_WINDOW_MS = 2 * 60 * 1000L // 2 分钟
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
     * 返回最近 2 分钟内在前台使用过的包名。
     *
     * Android 不允许第三方 App 直接读取“当前”前台 Activity，
     * 因此这里使用 UsageStatsManager 的常规替代方案：
     * 查询最近 2 分钟的 usage stats，取 lastTimeUsed 最新的包名。
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
}
