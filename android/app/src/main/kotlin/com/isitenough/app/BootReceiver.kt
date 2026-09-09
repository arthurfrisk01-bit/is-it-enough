package com.isitenough.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 开机 / 应用更新后自启后台监控服务。
 *
 * 只在用户确实开着“后台监控”开关时才启动：直接读取 shared_preferences 落盘的
 * 同一份配置（Flutter 侧写入的 key 前缀为 `flutter.`），避免用户关掉开关后
 * 每次开机又被拉起来。
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "IsItEnough/BootReceiver"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_MONITORING_ENABLED = "flutter.monitoring_enabled"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val isBoot = action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON"
        if (!isBoot) return

        val enabled = try {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getBoolean(KEY_MONITORING_ENABLED, true)
        } catch (t: Throwable) {
            Log.w(TAG, "读取监控开关失败，按开启处理", t)
            true
        }

        if (!enabled) {
            Log.i(TAG, "后台监控已关闭，跳过后台服务自启")
            LogStore.append(context, "开机/更新广播：监控开关为关，跳过自启", "Native")
            return
        }

        Log.i(TAG, "开机/更新完成，启动后台监控服务（action=$action）")
        LogStore.append(context, "开机/更新广播触发自启（action=$action）", "Native")
        MonitorForegroundService.start(context)
    }
}
