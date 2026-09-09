package com.isitenough.app

import android.animation.ValueAnimator
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.math.min

/**
 * 原生全屏提醒悬浮窗（WindowManager + TYPE_APPLICATION_OVERLAY）。
 *
 * ## 为什么不再用独立 Flutter 引擎画提醒
 *
 * 历史实现用 `flutter_overlay_window` 在独立 Flutter 引擎里渲染提醒。实机
 * (Xiaomi / HyperOS, Android 17) 上该引擎虽然缓存存在、executingDart=true，
 * 却始终不对 `shareData` 应答 —— 表现就是“日志里触发了提醒、用户只看到一条
 * 通知、永远没有前台全屏”。独立引擎冷启动 + 跨引擎握手本身就是脆弱链路，
 * 而且失败时几乎不可观测（隔离区没有原生日志桥）。
 *
 * 现在改为原生悬浮窗：
 * - 与 Flutter 引擎完全解耦：没有冷启动、没有跨引擎通信，`addView` 同步返回结果；
 * - 通过 SYSTEM_ALERT_WINDOW 直接覆盖在任意应用之上（这是“前台全屏”唯一可靠
 *   的机制 —— 系统通知的全屏 Intent 在屏幕点亮/解锁时会被系统降级成横幅）；
 * - 锁屏时悬浮窗不可见，此时返回 false，由系统通知的全屏 Intent 兜底；
 * - strong=全屏遮罩 + 小呼吸圆环，soft=顶部轻量卡片（不遮挡下方应用操作）。
 *
 * 视觉层级（2026-09 大版本调整）：主要信息是「哪个应用 + 已经用了多久」，
 * 呼吸圆环缩小到 120dp 作为陪衬，不再与文字抢注意力。
 *
 * 用户点击按钮后由 [ReminderOverlayBridge] 把 `snooze` / `putDown` / `focus`
 * 回传 Dart。
 */
object ReminderOverlay {

    private const val TAG = "IsItEnough/Overlay"

    /** 品牌色（与 Flutter 侧 Color(0xFF9ED8C4) 保持一致）。 */
    private val TEAL = 0xFF9ED8C4.toInt()
    private val INK = 0xFF101010.toInt()

    private val mainHandler = Handler(Looper.getMainLooper())

    /** 当前是否有悬浮窗显示在屏幕上（诊断用）。 */
    @Volatile
    var isShowing: Boolean = false
        private set

    private var root: View? = null
    private var windowManager: WindowManager? = null

    /** 是否已授予“显示在其他应用上层”权限。 */
    fun canDrawOverlays(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }

    /** 跳转系统悬浮窗授权页。 */
    fun requestPermission(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (t: Throwable) {
            Log.w(TAG, "打开悬浮窗授权页失败", t)
            LogStore.append(context, "打开悬浮窗授权页失败: ${t.message}", "Overlay")
        }
    }

    /**
     * 显示提醒悬浮窗。
     *
     * @return 窗口是否真的挂到了 WindowManager 上。同步返回，调用方据此决定
     *         要不要保留系统通知；不需要任何“回执/超时/补发”机制。
     */
    fun show(
        context: Context,
        mode: String,
        appName: String,
        snoozeMinutes: Int,
        continuousMinutes: Int,
        onAction: (String) -> Unit,
    ): Boolean {
        val app = context.applicationContext
        if (!canDrawOverlays(app)) {
            LogStore.append(app, "悬浮窗未显示：未授予“显示在其他应用上层”权限", "Overlay")
            return false
        }
        if (isKeyguardLocked(app)) {
            // 锁屏时悬浮窗被系统隐藏，交给通知的全屏 Intent 兜底。
            LogStore.append(app, "悬浮窗未显示：当前锁屏，改用全屏通知", "Overlay")
            return false
        }

        hide() // 幂等：先清掉上一轮的窗口

        return try {
            val strong = mode != "soft"
            val handle: (String) -> Unit = { action ->
                hide()
                onAction(action)
            }
            val view = if (strong) {
                buildStrong(app, appName, snoozeMinutes, continuousMinutes, handle)
            } else {
                buildWeak(app, appName, snoozeMinutes, continuousMinutes, handle)
            }
            val wm = app.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.addView(view, buildLayoutParams(app, strong))

            root = view
            windowManager = wm
            val attached = view.parent != null
            isShowing = attached
            if (strong) vibrate(app)
            LogStore.append(
                app,
                "悬浮窗已显示：模式=$mode 应用=$appName 已用=${continuousMinutes}分钟 附加=$attached",
                "Overlay",
            )
            // 尺寸要等一帧布局完成后再读，否则永远是 0x0（旧日志噪音来源）。
            view.post {
                LogStore.append(
                    app,
                    "悬浮窗实际尺寸=${view.width}x${view.height}",
                    "Overlay",
                )
            }
            attached
        } catch (t: Throwable) {
            Log.e(TAG, "显示悬浮窗失败", t)
            LogStore.append(app, "显示悬浮窗失败: ${t.javaClass.simpleName}: ${t.message}", "Overlay")
            hide()
            false
        }
    }

    /** 关闭悬浮窗（任意线程可调用）。 */
    fun hide() {
        if (Looper.myLooper() != Looper.getMainLooper()) {
            mainHandler.post { hide() }
            return
        }
        val view = root ?: return
        root = null
        isShowing = false
        try {
            windowManager?.removeViewImmediate(view)
        } catch (t: Throwable) {
            Log.w(TAG, "移除悬浮窗失败", t)
        }
        windowManager = null
    }

    private fun isKeyguardLocked(context: Context): Boolean = try {
        val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        km.isKeyguardLocked
    } catch (t: Throwable) {
        false
    }

    private fun vibrate(context: Context) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (!vibrator.hasVibrator()) return
            val pattern = longArrayOf(0, 400, 200, 400)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "震动失败: ${t.message}")
        }
    }

    private fun buildLayoutParams(context: Context, strong: Boolean): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        // FLAG_NOT_FOCUSABLE：不抢输入焦点（按钮点击照常工作）；
        // FLAG_NOT_TOUCH_MODAL：窗口外的触摸继续交给下层应用 —— soft 模式只占
        // 顶部一条，用户仍能操作下方应用，否则整屏点不动。
        var flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        if (strong) {
            flags = flags or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        }

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            if (strong) WindowManager.LayoutParams.MATCH_PARENT else WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            flags,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP
            if (!strong) y = context.dp(6f)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                layoutInDisplayCutoutMode = if (strong) {
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                } else {
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER
                }
            }
            setTitle("够了吗提醒")
        }
    }

    // ---------------------------------------------------------------- strong

    /**
     * 强提醒：全屏深色遮罩 + 大号主信息（应用名 + 已用时长）+ 小呼吸圆环 + 按钮。
     *
     * 视觉层级：应用名/时长是主角，呼吸圆环缩到 120dp 只做引导，不再与文字抢注意力。
     */
    private fun buildStrong(
        context: Context,
        appName: String,
        snoozeMinutes: Int,
        continuousMinutes: Int,
        onAction: (String) -> Unit,
    ): View {
        val rootView = FrameLayout(context).apply {
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(0xF00B0D12.toInt(), 0xF00E1A20.toInt(), 0xF0080A0E.toInt()),
            )
            // 全屏遮罩必须吃掉落在空白处的触摸，不能让事件漏给下层应用。
            isClickable = true
            setOnClickListener { /* 空白区域不做任何事 */ }
        }

        val column = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(context.dp(28f), context.dp(28f), context.dp(28f), context.dp(28f))
        }
        rootView.addView(
            column,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )

        column.addView(View(context), LinearLayout.LayoutParams(1, 0, 1.6f))

        // 小标签。
        column.addView(
            textView(context, "够了吗", 16f, 0x8AFFFFFF.toInt()).apply {
                gravity = Gravity.CENTER
                letterSpacing = 0.3f
            },
            wrap(),
        )

        // 主信息一：应用名（最大最亮）。
        column.addView(
            textView(context, appName, 40f, Color.WHITE, bold = true).apply {
                gravity = Gravity.CENTER
                letterSpacing = 0.04f
                setShadowLayer(26f, 0f, 0f, TEAL)
                setLayerType(View.LAYER_TYPE_SOFTWARE, null)
                setPadding(0, context.dp(10f), 0, 0)
            },
            wrap(),
        )

        // 主信息二：已用时长。
        column.addView(
            textView(
                context,
                "已连续使用 $continuousMinutes 分钟",
                17f,
                0xE6FFFFFF.toInt(),
            ).apply {
                gravity = Gravity.CENTER
                setPadding(0, context.dp(8f), 0, 0)
            },
            wrap(),
        )

        column.addView(View(context), LinearLayout.LayoutParams(1, 0, 1.2f))

        // 呼吸圆环（陪衬，120dp）。
        rootView.addView(
            BreathingRingView(context),
            FrameLayout.LayoutParams(context.dp(120f), context.dp(120f), Gravity.CENTER),
        )
        column.addView(View(context), LinearLayout.LayoutParams(1, context.dp(120f)))

        column.addView(
            textView(context, "跟随圆环，慢慢呼吸", 13f, 0x99A8E6C9.toInt()).apply {
                gravity = Gravity.CENTER
                letterSpacing = 0.05f
            },
            wrap(),
        )

        column.addView(View(context), LinearLayout.LayoutParams(1, 0, 1.6f))

        column.addView(
            pillButton(context, "现在放下", filled = true, textSize = 18f, vPad = 18f) {
                onAction("putDown")
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ),
        )
        column.addView(
            pillButton(context, snoozeLabel(snoozeMinutes), filled = false, textSize = 16f, vPad = 15f) {
                onAction("snooze")
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = context.dp(12f) },
        )
        // “专注勿扰”按钮：告诉软件自己在专注，1 小时内不要再打扰。
        column.addView(
            pillButton(
                context,
                "正在专注？1 小时内勿扰",
                filled = false,
                textSize = 14f,
                vPad = 12f,
            ) {
                onAction("focus")
            },
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = context.dp(12f) },
        )
        column.addView(
            textView(context, "提示：连续选择“再刷”超过 3 次，等待时间会缩短", 11f, 0x59FFFFFF.toInt()).apply {
                gravity = Gravity.CENTER
                setPadding(0, context.dp(16f), 0, 0)
            },
            wrap(),
        )

        return rootView
    }

    // ------------------------------------------------------------------ weak

    /** 弱提醒：顶部轻量卡片，不阻断下方应用操作。 */
    private fun buildWeak(
        context: Context,
        appName: String,
        snoozeMinutes: Int,
        continuousMinutes: Int,
        onAction: (String) -> Unit,
    ): View {
        val rootView = FrameLayout(context).apply {
            setPadding(context.dp(12f), context.dp(8f), context.dp(12f), 0)
        }

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(context.dp(20f), context.dp(16f), context.dp(16f), context.dp(16f))
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(0xF21C1B20.toInt(), 0xF2242330.toInt()),
            ).apply {
                cornerRadius = context.dp(20f).toFloat()
                setStroke(context.dp(1.5f), 0x339ED8C4.toInt())
            }
        }
        rootView.addView(
            card,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
            ),
        )

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        card.addView(header, wrap())

        header.addView(textView(context, "🌿", 20f, TEAL), wrap())
        header.addView(
            textView(context, "够了吗？", 19f, Color.WHITE, bold = true).apply {
                letterSpacing = 0.03f
            },
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                leftMargin = context.dp(8f)
            },
        )
        header.addView(
            textView(context, "✕", 18f, 0x8AFFFFFF.toInt()).apply {
                gravity = Gravity.CENTER
                isClickable = true
                setPadding(context.dp(6f), 0, 0, 0)
                setOnClickListener { onAction("snooze") }
            },
            wrap(),
        )

        // 主信息：应用名 + 已用时长。
        card.addView(
            textView(context, "$appName · 已用 $continuousMinutes 分钟", 15f, Color.WHITE, bold = true).apply {
                maxLines = 1
                setPadding(0, context.dp(10f), 0, 0)
            },
            wrap(),
        )
        card.addView(
            textView(context, "休息一下，让眼睛放松片刻", 12f, 0x999ED8C4.toInt()).apply {
                setPadding(0, context.dp(4f), 0, 0)
            },
            wrap(),
        )

        val actions = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        card.addView(
            actions,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = context.dp(18f) },
        )
        actions.addView(
            pillButton(context, snoozeLabel(snoozeMinutes), filled = false, textSize = 14f, vPad = 12f) {
                onAction("snooze")
            },
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        actions.addView(
            pillButton(context, "现在放下", filled = true, textSize = 14f, vPad = 12f) {
                onAction("putDown")
            },
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                leftMargin = context.dp(12f)
            },
        )

        // 专注勿扰入口（弱提醒里保持低调，避免抢主按钮）。
        card.addView(
            textView(context, "正在专注？点此 1 小时内勿扰", 12f, 0x8AFFFFFF.toInt()).apply {
                gravity = Gravity.CENTER
                isClickable = true
                setPadding(0, context.dp(14f), 0, 0)
                setOnClickListener { onAction("focus") }
            },
            wrap(),
        )

        return rootView
    }

    // --------------------------------------------------------------- helpers

    private fun snoozeLabel(snoozeMinutes: Int): String =
        if (snoozeMinutes <= 0) "再刷 30 秒" else "再刷 $snoozeMinutes 分钟"

    private fun wrap(): LinearLayout.LayoutParams =
        LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        )

    private fun textView(
        context: Context,
        value: String,
        sizeSp: Float,
        color: Int,
        bold: Boolean = false,
    ): TextView = TextView(context).apply {
        text = value
        setTextColor(color)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        typeface = Typeface.create(Typeface.DEFAULT, if (bold) Typeface.BOLD else Typeface.NORMAL)
    }

    /** 圆角胶囊按钮（TextView + GradientDrawable，避免引入 Material 依赖）。 */
    private fun pillButton(
        context: Context,
        label: String,
        filled: Boolean,
        textSize: Float,
        vPad: Float,
        onClick: () -> Unit,
    ): TextView = TextView(context).apply {
        text = label
        gravity = Gravity.CENTER
        setTextSize(TypedValue.COMPLEX_UNIT_SP, textSize)
        typeface = Typeface.create(Typeface.DEFAULT, if (filled) Typeface.BOLD else Typeface.NORMAL)
        setTextColor(if (filled) INK else 0xB3FFFFFF.toInt())
        background = GradientDrawable().apply {
            cornerRadius = context.dp(28f).toFloat()
            if (filled) {
                setColor(TEAL)
            } else {
                setColor(Color.TRANSPARENT)
                setStroke(context.dp(1.5f), 0x40FFFFFF.toInt())
            }
        }
        setPadding(context.dp(20f), context.dp(vPad), context.dp(20f), context.dp(vPad))
        isClickable = true
        setOnClickListener { onClick() }
    }

    /**
     * 呼吸圆环：8 秒一个来回，与 Flutter 侧 `BreathingPainter.cycleDuration` 一致。
     */
    private class BreathingRingView(context: Context) : View(context) {
        private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = TEAL
            strokeWidth = context.dp(4f).toFloat()
        }
        private val halo = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            color = TEAL
        }

        private var phase = 0f
        private var animator: ValueAnimator? = null

        init {
            animator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 4000L
                repeatCount = ValueAnimator.INFINITE
                repeatMode = ValueAnimator.REVERSE
                interpolator = LinearInterpolator()
                addUpdateListener {
                    phase = it.animatedValue as Float
                    invalidate()
                }
                start()
            }
        }

        override fun onDraw(canvas: Canvas) {
            val cx = width / 2f
            val cy = height / 2f
            val maxRadius = min(width, height) / 2f - ring.strokeWidth
            if (maxRadius <= 0f) return

            halo.alpha = (16 + 30 * phase).toInt()
            canvas.drawCircle(cx, cy, maxRadius * 0.44f, halo)

            ring.alpha = (150 + 105 * (1f - phase)).toInt()
            canvas.drawCircle(cx, cy, maxRadius * (0.55f + 0.45f * phase), ring)
        }

        override fun onDetachedFromWindow() {
            animator?.cancel()
            animator = null
            super.onDetachedFromWindow()
        }
    }
}

/** dp → px。 */
private fun Context.dp(value: Float): Int =
    TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, resources.displayMetrics).toInt()
