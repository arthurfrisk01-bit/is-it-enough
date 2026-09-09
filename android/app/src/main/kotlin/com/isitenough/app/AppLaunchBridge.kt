package com.isitenough.app

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * “现在放下”之后把 App 拉回前台并打开呼吸引导页。
 *
 * 背景（实机 bug）：提醒悬浮窗的点击可能由后台 headless 引擎处理，
 * 那里没有 Navigator，Dart 侧直接 push 呼吸页既看不到也不生效；
 * 界面引擎在后台时 push 也只会压在后台导航栈上，用户切回 App 才突然弹出。
 *
 * 所以统一走原生：拉起 MainActivity（singleTop），再把 openBreathing
 * 动作回传给界面引擎；界面引擎还没起来时先暂存，等 Dart 侧
 * AppLaunchChannel.init() 调 consumePendingAction 取走。
 */
class AppLaunchBridge(private val context: Context) {

    companion object {
        private const val TAG = "IsItEnough/AppLaunch"
        const val CHANNEL = "com.isitenough.app/launch"
        const val ACTION_OPEN_BREATHING = "openBreathing"

        @Volatile
        private var pendingAction: String? = null

        @Volatile
        private var uiChannel: MethodChannel? = null

        /**
         * 只有界面引擎会被记住：后台 headless 引擎也注册了本通道（要能发
         * openApp），但它没有 Navigator，把动作回传给它等于石沉大海。
         */
        fun attachUi(engine: FlutterEngine) {
            uiChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            Log.i(TAG, "界面引擎已接管启动通道")
        }

        fun detach() {
            uiChannel = null
        }

        /** 记下待处理动作（MainActivity 收到 extra 时调用）。 */
        fun setPending(action: String?) {
            pendingAction = action
            Log.i(TAG, "暂存启动动作: $action")
        }

        /** 界面引擎已就绪时，把暂存动作立刻回传给 Dart。 */
        fun deliverPending() {
            val action = pendingAction ?: return
            val channel = uiChannel ?: return
            pendingAction = null
            Handler(Looper.getMainLooper()).post {
                try {
                    channel.invokeMethod(action, null)
                } catch (t: Throwable) {
                    Log.w(TAG, "回传 $action 失败", t)
                }
            }
        }
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openApp" -> {
                        val openBreathing = call.argument<Boolean>("openBreathing") ?: false
                        result.success(bringToFront(openBreathing))
                    }
                    "consumePendingAction" -> {
                        val action = pendingAction
                        pendingAction = null
                        result.success(action)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun bringToFront(openBreathing: Boolean): Boolean {
        return try {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                if (openBreathing) putExtra(MainActivity.EXTRA_OPEN_BREATHING, true)
            }
            context.startActivity(intent)
            Log.i(TAG, "拉起 MainActivity，openBreathing=$openBreathing")
            LogStore.append(context, "“现在放下”把 App 拉回前台", "Native")
            true
        } catch (t: Throwable) {
            Log.e(TAG, "拉起 MainActivity 失败", t)
            LogStore.append(context, "拉起 App 失败: ${t.message}", "Native")
            // 拉起失败时退化为在当前引擎内跳转（界面引擎本来就活着的情况）。
            if (openBreathing) {
                uiChannel?.let { channel ->
                    Handler(Looper.getMainLooper()).post {
                        try {
                            channel.invokeMethod(ACTION_OPEN_BREATHING, null)
                        } catch (_: Throwable) {
                            // 忽略：headless 引擎没有界面，只能放弃。
                        }
                    }
                }
            }
            false
        }
    }
}
