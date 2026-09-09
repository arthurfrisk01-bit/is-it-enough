package com.isitenough.app

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngineCache
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * 系统状态快照采集器。
 *
 * 用于排查“通知不弹”类问题：把系统对本应用的**真实响应**一次性读出来
 * （通知总开关、各通道存在性与重要性、全屏 Intent 授权、省电/待机、
 * 服务存活、进程重要性、权限授予状态），导出到日志文件里。
 *
 * 每个小节独立 try/catch：某一段在个别 ROM 上抛异常不会影响整份报告。
 */
object DiagnosticsCollector {

    private val timeFmt = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)

    fun collect(context: Context): String {
        val sb = StringBuilder()
        sb.appendLine("########## 系统状态快照 ##########")
        sb.appendLine("采集时间: ${timeFmt.format(Date())}")
        sb.appendLine("时区: ${TimeZone.getDefault().id}")
        sb.appendLine()

        section(sb, "设备") { device(context) }
        section(sb, "应用") { app(context) }
        section(sb, "权限") { permissions(context) }
        section(sb, "通知（系统真实响应）") { notifications(context) }
        section(sb, "省电 / 待机 / 交互") { power(context) }
        section(sb, "服务与进程") { processes(context) }
        section(sb, "使用情况访问（UsageStats）") { usageAccess(context) }

        return sb.toString()
    }

    private inline fun section(sb: StringBuilder, title: String, body: () -> String) {
        sb.appendLine("--- $title ---")
        try {
            sb.append(body())
        } catch (t: Throwable) {
            sb.appendLine("  [采集失败] ${t.javaClass.simpleName}: ${t.message}")
        }
        sb.appendLine()
    }

    private fun device(context: Context): String {
        val sb = StringBuilder()
        sb.appendLine("  厂商/品牌: ${Build.MANUFACTURER} / ${Build.BRAND}")
        sb.appendLine("  机型: ${Build.MODEL} (device=${Build.DEVICE}, product=${Build.PRODUCT})")
        sb.appendLine("  系统: Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            sb.appendLine("  安全补丁: ${Build.VERSION.SECURITY_PATCH}")
        }
        sb.appendLine("  ABI: ${Build.SUPPORTED_ABIS.joinToString(", ")}")
        val cfg = context.resources.configuration
        sb.appendLine(
            "  屏幕: ${cfg.screenWidthDp}x${cfg.screenHeightDp}dp dpi=${cfg.densityDpi} " +
                "语言=${cfg.locales[0]} 方向=${if (cfg.orientation == 2) "横" else "竖"}"
        )
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        sb.appendLine("  低内存设备: ${am?.isLowRamDevice ?: "未知"}")
        return sb.toString()
    }

    private fun app(context: Context): String {
        val sb = StringBuilder()
        val pm = context.packageManager
        @Suppress("DEPRECATION")
        val info = pm.getPackageInfo(context.packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
        }
        sb.appendLine("  包名: ${context.packageName}")
        sb.appendLine("  版本: ${info.versionName} ($code)")
        sb.appendLine("  首次安装: ${timeFmt.format(Date(info.firstInstallTime))}")
        sb.appendLine("  最近更新: ${timeFmt.format(Date(info.lastUpdateTime))}")
        val ai = pm.getApplicationInfo(context.packageName, 0)
        sb.appendLine("  targetSdk: ${ai.targetSdkVersion} (debuggable=${(ai.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0})")
        val installer = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                pm.getInstallSourceInfo(context.packageName).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(context.packageName)
            }
        } catch (_: Throwable) {
            null
        }
        sb.appendLine("  安装来源: ${installer ?: "未知（侧载）"}")
        sb.appendLine("  数据目录: ${context.filesDir.absolutePath}")
        return sb.toString()
    }

    private fun permissions(context: Context): String {
        val sb = StringBuilder()
        sb.appendLine("  POST_NOTIFICATIONS: ${grantedText(context, "android.permission.POST_NOTIFICATIONS")}")
        sb.appendLine("  SYSTEM_ALERT_WINDOW(悬浮窗): ${Settings.canDrawOverlays(context)}")
        sb.appendLine("  RECEIVE_BOOT_COMPLETED: ${grantedText(context, "android.permission.RECEIVE_BOOT_COMPLETED")}")
        sb.appendLine("  FOREGROUND_SERVICE: ${grantedText(context, "android.permission.FOREGROUND_SERVICE")}")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            sb.appendLine(
                "  USE_FULL_SCREEN_INTENT: " +
                    grantedText(context, "android.permission.USE_FULL_SCREEN_INTENT")
            )
        }
        return sb.toString()
    }

    private fun notifications(context: Context): String {
        val sb = StringBuilder()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        sb.appendLine("  通知总开关(areNotificationsEnabled): ${nm.areNotificationsEnabled()}")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            sb.appendLine("  全屏通知可用(canUseFullScreenIntent): ${nm.canUseFullScreenIntent()}")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ids = listOf("reminder_strong", "reminder_soft", "reminder_silent", "monitor_keepalive")
            sb.appendLine("  通知通道:")
            for (id in ids) {
                val ch = nm.getNotificationChannel(id)
                if (ch == null) {
                    sb.appendLine("    - $id: 不存在（未创建！）")
                } else {
                    sb.appendLine(
                        "    - $id: 重要性=${importanceName(ch.importance)} " +
                            "声音=${ch.sound != null} 震动=${ch.shouldVibrate()} " +
                            "锁屏=${lockscreenName(ch.lockscreenVisibility)} " +
                            "可绕过勿扰=${ch.canBypassDnd()} 分组=${ch.group ?: "-"}"
                    )
                }
            }
        } else {
            sb.appendLine("  通知通道: Android 8 以下无通道概念")
        }

        try {
            val active = nm.activeNotifications
            sb.appendLine("  当前通知栏条数: ${active?.size ?: 0}")
            active?.forEach { sbn ->
                val channel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) sbn.notification.channelId else "-"
                sb.appendLine(
                    "    · id=${sbn.id} tag=${sbn.tag ?: "-"} 通道=$channel " +
                        "常驻=${sbn.isOngoing} 时间=${timeFmt.format(Date(sbn.postTime))}"
                )
            }
        } catch (t: Throwable) {
            sb.appendLine("  当前通知栏条数: 读取失败 ${t.message}")
        }
        return sb.toString()
    }

    private fun power(context: Context): String {
        val sb = StringBuilder()
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        sb.appendLine("  忽略电池优化: ${pm.isIgnoringBatteryOptimizations(context.packageName)}")
        sb.appendLine("  省电模式: ${pm.isPowerSaveMode}")
        sb.appendLine("  交互状态(亮屏): ${pm.isInteractive}")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            sb.appendLine("  Doze 待机: ${pm.isDeviceIdleMode}")
        }
        return sb.toString()
    }

    private fun processes(context: Context): String {
        val sb = StringBuilder()
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        sb.appendLine("  界面存活(MainActivity): ${MonitorForegroundService.uiAlive}")
        sb.appendLine("  保活服务运行中: ${isMonitorServiceRunning(am)}")
        sb.appendLine("  headless 引擎存活: ${MonitorForegroundService.isHeadlessEngineAlive()}")

        // Overlay 引擎：flutter_overlay_window 在 MainActivity 挂载时创建并缓存
        // （tag=myCachedEngine）。executingDart=false 说明 Overlay 隔离区压根没跑起来，
        // 那 shareData 必然超时、窗口只会是空白 —— 2026-09-09 排查"透明空窗"用的关键字段。
        try {
            val overlayEngine = FlutterEngineCache.getInstance().get("myCachedEngine")
            if (overlayEngine == null) {
                sb.appendLine("  Overlay 引擎: 未创建（插件未挂载/未缓存）")
            } else {
                sb.appendLine(
                    "  Overlay 引擎: 已缓存 executingDart=${overlayEngine.dartExecutor.isExecutingDart}"
                )
            }
        } catch (t: Throwable) {
            sb.appendLine("  Overlay 引擎: 读取失败 ${t.message}")
        }

        try {
            val state = ActivityManager.RunningAppProcessInfo()
            ActivityManager.getMyMemoryState(state)
            sb.appendLine("  进程重要性: ${processImportanceName(state.importance)} (${state.importance})")
            sb.appendLine("  进程名: ${state.processName} pid=${state.pid}")
        } catch (t: Throwable) {
            sb.appendLine("  进程重要性: 读取失败 ${t.message}")
        }
        return sb.toString()
    }

    private fun usageAccess(context: Context): String {
        val sb = StringBuilder()
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
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
        } catch (_: Throwable) {
            null
        }
        sb.appendLine("  PACKAGE_USAGE_STATS: ${mode == AppOpsManager.MODE_ALLOWED} (mode=$mode)")
        return sb.toString()
    }

    private fun grantedText(context: Context, permission: String): String {
        return try {
            val granted = context.checkPermission(permission, Process.myPid(), Process.myUid()) ==
                PackageManager.PERMISSION_GRANTED
            granted.toString()
        } catch (_: Throwable) {
            "检查失败"
        }
    }

    private fun isMonitorServiceRunning(am: ActivityManager): Boolean {
        return try {
            @Suppress("DEPRECATION")
            am.getRunningServices(200).any {
                it.service.className == MonitorForegroundService::class.java.name
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun importanceName(importance: Int): String = when (importance) {
        NotificationManager.IMPORTANCE_NONE -> "NONE(已关闭)"
        NotificationManager.IMPORTANCE_MIN -> "MIN"
        NotificationManager.IMPORTANCE_LOW -> "LOW"
        NotificationManager.IMPORTANCE_DEFAULT -> "DEFAULT"
        NotificationManager.IMPORTANCE_HIGH -> "HIGH"
        NotificationManager.IMPORTANCE_MAX -> "MAX"
        else -> "未知($importance)"
    }

    private fun lockscreenName(visibility: Int): String = when (visibility) {
        android.app.Notification.VISIBILITY_SECRET -> "SECRET"
        android.app.Notification.VISIBILITY_PRIVATE -> "PRIVATE"
        android.app.Notification.VISIBILITY_PUBLIC -> "PUBLIC"
        else -> "未知($visibility)"
    }

    private fun processImportanceName(importance: Int): String = when (importance) {
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> "FOREGROUND"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE -> "FOREGROUND_SERVICE"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE -> "VISIBLE"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE -> "SERVICE"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED -> "CACHED(可被回收)"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_EMPTY -> "EMPTY"
        else -> "其他"
    }
}