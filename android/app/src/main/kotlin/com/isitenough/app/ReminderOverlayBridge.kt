package com.isitenough.app

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 原生提醒悬浮窗 ↔ Dart 的桥。
 *
 * 通道：`com.isitenough.app/reminder_overlay`
 *
 * Dart → 原生：`isPermissionGranted` / `requestPermission` / `isShowing` /
 *              `show` / `hide`
 * 原生 → Dart：`action`（`snooze` / `putDown`，用户点了悬浮窗上的按钮）
 *
 * 与 AppBridges 里其它通道一样，**每个引擎都要注册**（界面引擎和 headless
 * 引擎），否则后台触发提醒时调用直接 MissingPluginException。
 */
class ReminderOverlayBridge(private val context: Context) {

    companion object {
        const val CHANNEL = "com.isitenough.app/reminder_overlay"
        private const val TAG = "IsItEnough/OverlayBridge"
    }

    fun register(engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isPermissionGranted" ->
                        result.success(ReminderOverlay.canDrawOverlays(context))

                    "requestPermission" -> {
                        ReminderOverlay.requestPermission(context)
                        result.success(null)
                    }

                    "isShowing" -> result.success(ReminderOverlay.isShowing)

                    "show" -> {
                        val mode = call.argument<String>("mode") ?: "soft"
                        val appName = call.argument<String>("appName") ?: ""
                        val snoozeMinutes = call.argument<Int>("snoozeMinutes") ?: 5
                        val continuousMinutes = call.argument<Int>("continuousMinutes") ?: 0
                        val shown = ReminderOverlay.show(
                            context = context,
                            mode = mode,
                            appName = appName,
                            snoozeMinutes = snoozeMinutes,
                            continuousMinutes = continuousMinutes,
                        ) { action ->
                            try {
                                channel.invokeMethod("action", action)
                            } catch (t: Throwable) {
                                // 回传失败说明宿主引擎已销毁：立刻关窗，
                                // 否则按钮失效、悬浮窗会一直挡住屏幕。
                                LogStore.append(
                                    context,
                                    "回传悬浮窗操作失败，关闭窗口: ${t.message}",
                                    "Overlay",
                                )
                                ReminderOverlay.hide()
                            }
                        }
                        result.success(shown)
                    }

                    "hide" -> {
                        ReminderOverlay.hide()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                Log.e(TAG, "悬浮窗通道异常: ${call.method}", t)
                LogStore.append(context, "悬浮窗通道异常(${call.method}): ${t.message}", "Overlay")
                result.error("overlay_error", t.message, null)
            }
        }
    }
}
