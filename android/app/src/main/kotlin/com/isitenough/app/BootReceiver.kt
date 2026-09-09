package com.isitenough.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 开机 / 应用更新后自启后台监控服务。
 *
 * 只有两个开关都打开时才启动：
 * - `flutter.monitoring_enabled`（后台监控总开关）；
 * - `flutter.auto_start_enabled`（设置页的“开机自启动”开关）。
 *
 * 直接读取 shared_preferences 落盘的同一份配置（Flutter 侧写入的 key 前缀为
 * `flutter.`），避免用户关掉开关后每次开机又被拉起来。
 *
 * 去重：部分 ROM 在开机时会连发两次 BOOT_COMPLETED（甚至叠加 QUICKBOOT_POWERON），
 * 旧实现会重复启动服务、重复创建保活通知。这里对同一 action 做 10 秒静默窗口。
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "IsItEnough/BootReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_MONITORING_ENABLED = "flutter.monitoring_enabled"
        private const val KEY_AUTO_START_ENABLED = "flutter.auto_start_enabled"

        /** 同一 action 的重复广播静默窗口。 */
        private const val DEDUPE_WINDOW_MS = 10_000L

        @Volatile
        private var lastAction: String? = null

        @Volatile
        private var lastHandledAt: Long = 0L
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val isBoot = action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON"
        if (!isBoot) return

        // 去重：同一 action 在 10 秒内重复到达时直接忽略（MIUI 等 ROM 会连发）。
        val now = System.currentTimeMillis()
        if (action == lastAction && now - lastHandledAt < DEDUPE_WINDOW_MS) {
            Log.i(TAG, "忽略重复广播 action=$action（${now - lastHandledAt}ms 内已处理）")
            return
        }
        lastAction = action
        lastHandledAt = now

        val prefs = try {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        } catch (t: Throwable) {
            Log.w(TAG, "读取配置失败，按开启处理", t)
            null
        }

        val monitoringEnabled = try {
            prefs?.getBoolean(KEY_MONITORING_ENABLED, true) ?: true
        } catch (t: Throwable) {
            true
        }
        val autoStartEnabled = try {
            prefs?.getBoolean(KEY_AUTO_START_ENABLED, true) ?: true
        } catch (t: Throwable) {
            true
        }

        if (!monitoringEnabled) {
            Log.i(TAG, "后台监控已关闭，跳过后台服务自启")
            LogStore.append(context, "开机/更新广播：监控开关为关，跳过自启", "Native")
            return
        }
        if (!autoStartEnabled) {
            Log.i(TAG, "开机自启动已关闭，跳过后台服务自启")
            LogStore.append(context, "开机/更新广播：自启动开关为关，跳过自启", "Native")
            return
        }

        Log.i(TAG, "开机/更新完成，启动后台监控服务（action=$action）")
        LogStore.append(context, "开机/更新广播触发自启（action=$action）", "Native")
        MonitorForegroundService.start(context)
    }
}
