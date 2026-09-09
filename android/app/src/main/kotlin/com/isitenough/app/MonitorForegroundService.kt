package com.isitenough.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.MethodChannel

/**
 * 后台监控保活前台服务。
 *
 * 三件事：
 * 1. 常驻低优先级前台通知，把进程提升为 foreground 优先级，
 *    降低被 ROM / 低内存回收的概率；
 * 2. 常驻通知动态显示“当前应用 + 已使用时长”（由 Dart 侧每轮轮询推送，
 *    见 [updateStatus]），让用户一眼看到自己正在刷什么、刷了多久；
 * 3. 当 App 界面不存在时（开机自启、进程被系统回收后由 START_STICKY 重建），
 *    拉起一个无界面的 Flutter 引擎执行 `monitorMain` 入口，让监控继续工作。
 *
 * 互斥：界面存活时（[uiAlive] == true）不创建 headless 引擎，
 * 界面创建时主动销毁已存在的 headless 引擎，避免两个引擎同时轮询造成重复提醒。
 */
class MonitorForegroundService : Service() {

    companion object {
        private const val TAG = "IsItEnough/MonitorService"
        private const val CHANNEL_ID = "monitor_keepalive"
        private const val NOTIFICATION_ID = 1002
        private const val DART_ENTRYPOINT = "monitorMain"

        private const val ACTION_START = "com.isitenough.app.action.START_MONITOR_SERVICE"
        private const val ACTION_STOP = "com.isitenough.app.action.STOP_MONITOR_SERVICE"

        private const val DEFAULT_TEXT = "正在后台守护你的专注，点击打开"

        /** App 界面是否存活，由 MainActivity 维护。 */
        @Volatile
        var uiAlive: Boolean = false

        @Volatile
        private var headlessEngine: FlutterEngine? = null

        /** 服务是否已进入前台（决定 [updateStatus] 能不能改通知）。 */
        @Volatile
        private var running: Boolean = false

        /** 当前通知正文，避免同一内容反复 notify。 */
        @Volatile
        private var currentText: String = DEFAULT_TEXT

        /** headless 引擎是否存活（诊断用）。 */
        fun isHeadlessEngineAlive(): Boolean = headlessEngine != null

        /** 启动保活服务（幂等）。 */
        fun start(context: Context) {
            val intent = Intent(context, MonitorForegroundService::class.java).setAction(ACTION_START)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                LogStore.append(context, "请求启动后台监控服务", "Native")
            } catch (t: Throwable) {
                Log.e(TAG, "启动后台监控服务失败", t)
                LogStore.append(context, "启动后台监控服务失败: ${t.message}", "Native")
            }
        }

        /** 停止保活服务。 */
        fun stop(context: Context) {
            val intent = Intent(context, MonitorForegroundService::class.java).setAction(ACTION_STOP)
            try {
                context.startService(intent)
            } catch (t: Throwable) {
                Log.e(TAG, "停止后台监控服务失败", t)
            }
        }

        /**
         * 更新常驻通知正文（当前应用 + 使用时长）。
         *
         * 由 Dart 侧 [ForegroundMonitor] 每轮轮询调用；服务未运行时静默忽略，
         * 避免在用户关掉后台监控后凭空冒出一条通知。
         */
        fun updateStatus(context: Context, text: String) {
            if (!running) return
            if (text == currentText) return
            currentText = text
            try {
                val manager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.notify(NOTIFICATION_ID, buildNotification(context, text))
            } catch (t: Throwable) {
                Log.w(TAG, "更新常驻通知失败: ${t.message}")
            }
        }

        /** App 界面创建时调用：销毁无界面引擎，由界面引擎接管监控。 */
        fun releaseHeadlessEngine(context: Context? = null) {
            headlessEngine?.let { engine ->
                Log.i(TAG, "界面已创建，销毁 headless FlutterEngine")
                context?.let { LogStore.append(it, "销毁 headless 引擎（界面接管）", "Native") }
                try {
                    engine.destroy()
                } catch (t: Throwable) {
                    Log.w(TAG, "销毁 headless FlutterEngine 失败", t)
                }
            }
            headlessEngine = null
        }

        /** 构造常驻通知；[text] 为动态正文。 */
        private fun buildNotification(context: Context, text: String): Notification {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val contentIntent = PendingIntent.getActivity(context, 0, intent, pendingFlags)

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }

            return builder
                .setContentTitle("够了吗")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentIntent(contentIntent)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        running = true
        currentText = DEFAULT_TEXT
        promoteToForeground()
        LogStore.append(this, "保活服务 onCreate（前台通知已提升）", "Native")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                releaseHeadlessEngine(this)
                stopSelf()
                LogStore.append(this, "收到停止指令，保活服务退出", "Native")
                return START_NOT_STICKY
            }
            else -> {
                // 仅当 App 界面不存在时才需要无界面引擎。
                if (!uiAlive) {
                    ensureHeadlessEngine()
                }
            }
        }
        // 被系统回收后自动重建，尽量让监控不中断。
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        releaseHeadlessEngine(this)
        LogStore.append(this, "保活服务 onDestroy", "Native")
        super.onDestroy()
    }

    /** 提升为前台服务，常驻通知用最低优先级避免打扰。 */
    private fun promoteToForeground() {
        val notification = buildNotification(this, DEFAULT_TEXT)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "startForeground 失败", t)
            LogStore.append(this, "startForeground 失败: ${t.message}", "Native")
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "后台守护",
            NotificationManager.IMPORTANCE_MIN,
        ).apply {
            description = "保持监控在后台运行的常驻通知，不响铃不震动"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
            enableLights(false)
        }
        manager.createNotificationChannel(channel)
    }

    /**
     * 创建无界面 Flutter 引擎并执行 `monitorMain` 入口。
     *
     * 失败时只记日志：服务继续保活，App 界面侧的监控不受影响。
     */
    private fun ensureHeadlessEngine() {
        if (headlessEngine != null) return
        try {
            val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)

            val engine = FlutterEngine(applicationContext)
            // 必须为 headless 引擎注册原生通道：
            // - UsageStatsBridge：否则 Dart 侧 getForegroundPackage 抛
            //   MissingPluginException，后台监控静默失效（不弹提醒）；
            // - LogBridge：让后台引擎的日志也落进同一份日志文件。
            AppBridges.registerAll(engine, applicationContext)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), DART_ENTRYPOINT)
            )
            headlessEngine = engine
            Log.i(TAG, "headless FlutterEngine 已启动（entrypoint=$DART_ENTRYPOINT）")
            LogStore.append(this, "headless 引擎已启动（entrypoint=$DART_ENTRYPOINT）", "Native")
        } catch (t: Throwable) {
            Log.e(TAG, "headless FlutterEngine 启动失败，监控暂时只能依赖界面进程", t)
            LogStore.append(this, "headless 引擎启动失败: ${t.message}", "Native")
            headlessEngine = null
        }
    }
}
