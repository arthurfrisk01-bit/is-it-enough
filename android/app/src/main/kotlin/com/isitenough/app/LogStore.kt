package com.isitenough.app

import android.content.Context
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 原生侧日志落盘。
 *
 * 所有日志统一追加到 `<内部存储>/files/logs/app.log`：
 * - 原生代码（服务启停、引擎创建、通知通道、异常）直接调用 [append]；
 * - 各个 Flutter 引擎（界面 / 后台 headless / Overlay）通过
 *   `com.isitenough.app/log` 通道写入同一份文件。
 *
 * 因此导出时能拿到“跨引擎 + 跨进程”的全量日志，而不是某个 isolate 的内存队列。
 * 文件超过上限时保留尾部，避免无限增长。
 */
object LogStore {

    private const val TAG = "IsItEnough/LogStore"
    private const val FILE_NAME = "app.log"
    private const val MAX_BYTES = 4L * 1024 * 1024
    private const val KEEP_BYTES = 2L * 1024 * 1024

    private val lock = Any()
    private val stamp = SimpleDateFormat("MM-dd HH:mm:ss.SSS", Locale.US)

    fun dir(context: Context): File = File(context.filesDir, "logs")

    fun file(context: Context): File = File(dir(context), FILE_NAME)

    /** 追加一行日志；任何异常都只写 logcat，绝不向外抛。 */
    fun append(context: Context, message: String, tag: String? = null) {
        val line = synchronized(lock) {
            val head = stamp.format(Date())
            "[$head]${if (tag.isNullOrEmpty()) "" else "[$tag]"} $message"
        }
        synchronized(lock) {
            try {
                val d = dir(context)
                if (!d.exists()) d.mkdirs()
                val f = File(d, FILE_NAME)
                if (f.exists() && f.length() > MAX_BYTES) truncate(f)
                f.appendText(line + "\n", Charsets.UTF_8)
            } catch (t: Throwable) {
                Log.w(TAG, "写入日志文件失败: ${t.message}")
            }
        }
    }

    /** 读取全部日志文本；文件不存在时返回空串。 */
    fun readAll(context: Context): String = synchronized(lock) {
        try {
            val f = file(context)
            if (!f.exists()) "" else f.readText(Charsets.UTF_8)
        } catch (t: Throwable) {
            Log.w(TAG, "读取日志文件失败: ${t.message}")
            ""
        }
    }

    /** 清空日志文件。 */
    fun clear(context: Context) {
        synchronized(lock) {
            try {
                file(context).delete()
            } catch (t: Throwable) {
                Log.w(TAG, "清空日志文件失败: ${t.message}")
            }
        }
    }

    /** 只保留尾部 [KEEP_BYTES]，避免文件无限增长。 */
    private fun truncate(f: File) {
        try {
            val length = f.length()
            val skip = (length - KEEP_BYTES).coerceAtLeast(0)
            val tail = f.inputStream().use { input ->
                var skipped = 0L
                while (skipped < skip) {
                    val n = input.skip(skip - skipped)
                    if (n <= 0) break
                    skipped += n
                }
                input.readBytes()
            }
            val tmp = File(f.parentFile, "$FILE_NAME.tmp")
            tmp.writeBytes(tail)
            if (!tmp.renameTo(f)) {
                f.writeBytes(tail)
                tmp.delete()
            }
        } catch (t: Throwable) {
            Log.w(TAG, "截断日志文件失败: ${t.message}")
        }
    }
}
