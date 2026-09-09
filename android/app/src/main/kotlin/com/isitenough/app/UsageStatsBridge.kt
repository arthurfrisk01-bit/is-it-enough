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
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * UsageStatsManager MethodChannel 桥。
 *
 * 提供四个能力：
 * 1. isUsageAccessGranted    —— 当前是否已授予“使用情况访问权限”
 * 2. openUsageAccessSettings —— 跳转系统使用情况访问设置页
 * 3. getForegroundPackage    —— 通过 UsageStatsManager 推断当前前台应用包名
 * 4. getAppLabel             —— 包名 → 应用显示名（“微信”而不是 com.tencent.mm）
 * 5. getUsageTimeline        —— 今日各应用使用会话（统计页时间线 + 使用量）
 */
class UsageStatsBridge(
    engine: FlutterEngine,
    private val context: Context,
) : MethodCallHandler {

    companion object {
        private const val CHANNEL = "com.isitenough.app/usage_stats"
        private const val LOOKBACK_WINDOW_MS = 2 * 60 * 1000L // 2 分钟（聚合法回退窗口）

        /**
         * 事件法查询窗口：6 小时。
         *
         * 旧值 1 小时会让“连续使用超过 1 小时且中间没有 Activity 切换”的场景
         * （刷视频、看小说）在窗口内找不到有效事件，退化为聚合法（取
         * lastTimeUsed 最大），容易被桌面/最近任务带偏，进而导致会话反复
         * 停靠+恢复、累计时间被重置。6 小时覆盖绝大多数单次连续使用。
         */
        private const val EVENT_LOOKBACK_MS = 6 * 60 * 60 * 1000L

        /** 时间线里忽略的过短会话（毫秒），避免返回大量瞬跳记录。 */
        private const val MIN_SESSION_MS = 1_000L

        /** 单个应用最多返回的会话数，控制 JSON 体积。 */
        private const val MAX_SESSIONS_PER_APP = 40
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
            "getUsageTimeline" -> getUsageTimeline(call, result)
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
                LogStore.append(context, "前台查询失败：未授予“使用情况访问权限”", "Native")
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
            LogStore.append(context, "前台查询 SecurityException: ${e.message}", "Native")
            result.error(
                "USAGE_ACCESS_REQUIRED",
                "缺少使用情况访问权限：${e.message}",
                e.stackTraceToString(),
            )
        } catch (e: Exception) {
            LogStore.append(context, "前台查询异常: ${e.javaClass.simpleName}: ${e.message}", "Native")
            result.error("GET_FOREGROUND_FAILED", e.message, e.stackTraceToString())
        }
    }

    /**
     * 事件法推断前台包名。
     *
     * 规则：最近一个 RESUME 的包为前台；该包出现 PAUSED/STOPPED 后视为离开
     * （期间有新的 RESUME 则换人）。
     *
     * 返回值三态：
     * - 非空包名：确定的前台应用；
     * - 空串 ""：确定“没有前台应用”（熄屏），调用方应停靠会话而不是回退聚合法；
     * - null：窗口内无法判定，由调用方回退聚合法。
     */
    private fun inferForegroundFromEvents(
        usageStatsManager: UsageStatsManager,
        begin: Long,
        end: Long,
    ): String? {
        val events = usageStatsManager.queryEvents(begin, end)
        val event = android.app.usage.UsageEvents.Event()
        var current: String? = null
        var screenOff = false
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName
            when (event.eventType) {
                android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (pkg != null) current = pkg
                }
                android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED,
                android.app.usage.UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (pkg != null && pkg == current) current = null
                }
                // SCREEN_* 事件仅 API 28+ 会上报；常量编译期内联，低版本不会命中。
                android.app.usage.UsageEvents.Event.SCREEN_INTERACTIVE -> {
                    screenOff = false
                }
                android.app.usage.UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                    // 熄屏后不存在“前台应用”。若不显式置空，锁屏几小时后
                    // 窗口内最后一个 RESUME 仍会被当成当前前台应用。
                    screenOff = true
                    current = null
                }
            }
        }
        if (screenOff) return ""
        return current
    }

    /**
     * 今日（可指定天数）各应用使用会话。
     *
     * 返回 JSON 字符串，结构：
     * `{"start":ms,"end":ms,"apps":[{"package":"..","label":"微信","totalMs":n,
     *   "sessions":[{"start":ms,"end":ms}]}]}`
     *
     * 无权限时返回 null，由 Dart 侧提示用户授权。
     */
    private fun getUsageTimeline(call: MethodCall, result: Result) {
        try {
            if (!isUsageAccessGranted()) {
                LogStore.append(context, "使用量查询失败：未授予“使用情况访问权限”", "Native")
                result.success(null)
                return
            }

            val days = (call.argument<Int>("days") ?: 1).coerceIn(1, 7)
            val calendar = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, -(days - 1))
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val begin = calendar.timeInMillis
            val now = System.currentTimeMillis()

            val usageStatsManager =
                context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val events = usageStatsManager.queryEvents(begin, now)
            val event = android.app.usage.UsageEvents.Event()

            val openStarts = HashMap<String, Long>()
            val sessions = HashMap<String, MutableList<LongArray>>()
            var screenOff = false

            fun closeSession(pkg: String, end: Long) {
                val start = openStarts.remove(pkg) ?: return
                if (end - start < MIN_SESSION_MS) return
                sessions.getOrPut(pkg) { mutableListOf() }.add(longArrayOf(start, end))
            }

            fun closeAll(end: Long) {
                for (pkg in openStarts.keys.toList()) closeSession(pkg, end)
            }

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val pkg = event.packageName ?: continue
                when (event.eventType) {
                    android.app.usage.UsageEvents.Event.ACTIVITY_RESUMED -> {
                        // 同一时刻可能残留其它包的开放会话（事件缺失时），先收口。
                        if (!openStarts.containsKey(pkg)) openStarts[pkg] = event.timeStamp
                    }
                    android.app.usage.UsageEvents.Event.ACTIVITY_PAUSED,
                    android.app.usage.UsageEvents.Event.ACTIVITY_STOPPED -> {
                        closeSession(pkg, event.timeStamp)
                    }
                    android.app.usage.UsageEvents.Event.SCREEN_NON_INTERACTIVE -> {
                        closeAll(event.timeStamp)
                        screenOff = true
                    }
                    android.app.usage.UsageEvents.Event.SCREEN_INTERACTIVE -> {
                        screenOff = false
                    }
                }
            }
            // 仍在使用的会话：屏幕亮着就补到“现在”，熄屏则丢弃（没有终点）。
            if (!screenOff) closeAll(now)

            val appsJson = JSONArray()
            for ((pkg, list) in sessions) {
                if (pkg == context.packageName) continue
                val total = list.sumOf { it[1] - it[0] }
                val sorted = list.sortedByDescending { it[1] }.take(MAX_SESSIONS_PER_APP)
                val sessionJson = JSONArray()
                for (s in sorted) {
                    sessionJson.put(
                        JSONObject()
                            .put("start", s[0])
                            .put("end", s[1]),
                    )
                }
                appsJson.put(
                    JSONObject()
                        .put("package", pkg)
                        .put("label", labelFor(pkg))
                        .put("totalMs", total)
                        .put("sessions", sessionJson),
                )
            }

            val root = JSONObject()
                .put("start", begin)
                .put("end", now)
                .put("apps", appsJson)
            result.success(root.toString())
        } catch (e: SecurityException) {
            result.error(
                "USAGE_ACCESS_REQUIRED",
                "缺少使用情况访问权限：${e.message}",
                e.stackTraceToString(),
            )
        } catch (e: Exception) {
            LogStore.append(context, "使用量查询异常: ${e.javaClass.simpleName}: ${e.message}", "Native")
            result.error("GET_USAGE_TIMELINE_FAILED", e.message, e.stackTraceToString())
        }
    }

    /** 获取应用名称（通过包名查询 ApplicationInfo）。 */
    private fun getAppLabel(call: MethodCall, result: Result) {
        try {
            val packageName = call.argument<String>("packageName")
            if (packageName.isNullOrEmpty()) {
                result.error("INVALID_ARGUMENT", "packageName is required", null)
                return
            }
            result.success(labelFor(packageName))
        } catch (e: Exception) {
            result.error("GET_APP_LABEL_FAILED", e.message, e.stackTraceToString())
        }
    }

    /**
     * 包名 → 应用显示名。
     *
     * Android 11+ 受包可见性限制时 `getApplicationInfo` 会抛
     * NameNotFoundException；manifest 里已声明 LAUNCHER intent 查询，
     * 正常情况下能拿到「微信」。仍失败时回退为包名最后一段（比整串包名可读）。
     */
    private fun labelFor(packageName: String): String {
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName.substringAfterLast('.', packageName)
        }
    }
}
