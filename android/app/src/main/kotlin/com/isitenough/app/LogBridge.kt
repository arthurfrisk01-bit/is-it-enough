package com.isitenough.app

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 日志通道 `com.isitenough.app/log`。
 *
 * 每个 Flutter 引擎（界面 / headless 后台 / 其他）都注册一份，Dart 侧
 * [LoggerService] 把每条日志追加到同一份原生日志文件，从而做到
 * “跨引擎全量收集”。导出时把日志文件 + 系统状态快照 + 当前设置写成
 * 一个 txt 落到系统“下载”目录。
 */
class LogBridge(private val context: Context) {

    companion object {
        const val CHANNEL = "com.isitenough.app/log"
        private const val TAG = "IsItEnough/LogBridge"
        private const val EXPORT_DIR = "IsItEnough"
        private const val MAX_SHARE_TEXT = 200_000
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "append" -> {
                        LogStore.append(
                            context,
                            call.argument<String>("line").orEmpty(),
                            call.argument<String>("tag"),
                        )
                        result.success(null)
                    }

                    "read" -> result.success(LogStore.readAll(context))

                    "clear" -> {
                        LogStore.clear(context)
                        result.success(null)
                    }

                    "diagnostics" -> result.success(DiagnosticsCollector.collect(context))

                    "export" -> export(
                        call.argument<String>("content").orEmpty(),
                        call.argument<String>("name"),
                        result,
                    )

                    "share" -> share(
                        call.argument<String>("uri"),
                        call.argument<String>("text"),
                        result,
                    )

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 把导出内容写入系统“下载”目录，返回 {path, uri}。
     * uri 在 Android 10+ 由 MediaStore 提供，可直接分享；低版本为 null。
     */
    private fun export(content: String, name: String?, result: MethodChannel.Result) {
        val fileName = name?.takeIf { it.isNotBlank() }
            ?: "isitenough-log-${SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())}.txt"
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val saved = exportViaMediaStore(content, fileName)
                if (saved != null) {
                    result.success(mapOf("path" to saved.first, "uri" to saved.second.toString()))
                    return
                }
            }
            // Android 9 及以下，或 MediaStore 失败：直接写公共下载目录。
            val legacy = exportToPublicDownloads(content, fileName)
            if (legacy != null) {
                result.success(mapOf("path" to legacy.absolutePath, "uri" to null))
                return
            }
            // 最后兜底：写应用外部目录（无需权限，文件管理器可访问）。
            val fallbackDir = File(context.getExternalFilesDir(null) ?: context.filesDir, "logs")
            if (!fallbackDir.exists()) fallbackDir.mkdirs()
            val fallback = File(fallbackDir, fileName)
            fallback.writeText(content, Charsets.UTF_8)
            result.success(mapOf("path" to fallback.absolutePath, "uri" to null))
        } catch (t: Throwable) {
            Log.e(TAG, "导出日志失败", t)
            result.error("EXPORT_FAILED", t.message, null)
        }
    }

    /** Android 10+：通过 MediaStore 写入“下载/IsItEnough”，返回展示路径与分享 URI。 */
    private fun exportViaMediaStore(content: String, fileName: String): Pair<String, Uri>? {
        return try {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + File.separator + EXPORT_DIR,
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return null
            resolver.openOutputStream(uri)?.use { it.write(content.toByteArray(Charsets.UTF_8)) }
                ?: return null
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            val path = "${Environment.DIRECTORY_DOWNLOADS}/$EXPORT_DIR/$fileName"
            path to uri
        } catch (t: Throwable) {
            Log.w(TAG, "MediaStore 导出失败，回退公共目录: ${t.message}")
            null
        }
    }

    /** Android 9 及以下：写 /storage/emulated/0/Download/IsItEnough/。 */
    private fun exportToPublicDownloads(content: String, fileName: String): File? {
        return try {
            @Suppress("DEPRECATION")
            val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val dir = File(downloads, EXPORT_DIR)
            if (!dir.exists() && !dir.mkdirs()) return null
            val file = File(dir, fileName)
            file.writeText(content, Charsets.UTF_8)
            file
        } catch (t: Throwable) {
            Log.w(TAG, "写入公共下载目录失败: ${t.message}")
            null
        }
    }

    /** 分享日志：优先分享文件 URI；没有 URI 时降级为分享文本（截断）。 */
    private fun share(uriString: String?, text: String?, result: MethodChannel.Result) {
        try {
            val send = Intent(Intent.ACTION_SEND).apply {
                if (!uriString.isNullOrBlank()) {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_STREAM, Uri.parse(uriString))
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } else {
                    type = "text/plain"
                    val body = text.orEmpty()
                    putExtra(
                        Intent.EXTRA_TEXT,
                        if (body.length > MAX_SHARE_TEXT) {
                            body.take(MAX_SHARE_TEXT) + "\n\n…（日志过长已截断，完整内容见已保存的文件）"
                        } else {
                            body
                        },
                    )
                }
                putExtra(Intent.EXTRA_SUBJECT, "够了吗 调试日志")
            }
            val chooser = Intent.createChooser(send, "分享调试日志").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(chooser)
            result.success(true)
        } catch (t: Throwable) {
            Log.e(TAG, "分享日志失败", t)
            result.error("SHARE_FAILED", t.message, null)
        }
    }
}
