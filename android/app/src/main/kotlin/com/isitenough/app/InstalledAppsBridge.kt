package com.isitenough.app

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * 读取本机已安装应用列表 + 本应用安装来源自检。
 *
 * 用途：
 * - 名单模式（黑名单/白名单）的应用选择页需要完整应用清单；
 * - “低授信/受限设置”自检需要知道安装来源（Play / 侧载 / adb）。
 *
 * 隐私：只读取包名、应用名、是否系统应用、安装来源等公开信息，
 * 全部留在本机，不联网、不上传。
 */
class InstalledAppsBridge(private val context: Context) {

    companion object {
        const val CHANNEL = "com.isitenough.app/installed_apps"
    }

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listLaunchableApps" -> result.success(listLaunchableApps())
                    "getSelfInstallInfo" -> result.success(selfInstallInfo())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 带桌面图标的应用列表（JSON 字符串）。
     *
     * 依赖 Manifest 里 `MAIN` + `LAUNCHER` 的 <queries> 声明，
     * 无需 QUERY_ALL_PACKAGES 就能看到用户可见的应用。
     */
    private fun listLaunchableApps(): String {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val infos = try {
            pm.queryIntentActivities(intent, 0)
        } catch (t: Throwable) {
            LogStore.append(context, "读取已装应用列表失败: ${t.message}", "Native")
            emptyList()
        }
        val seen = HashSet<String>()
        val rows = ArrayList<JSONObject>()
        for (info in infos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == context.packageName) continue
            if (!seen.add(pkg)) continue
            val appInfo = info.activityInfo.applicationInfo ?: continue
            val label = runCatching { pm.getApplicationLabel(appInfo).toString() }
                .getOrElse { pkg }
            val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            rows.add(
                JSONObject()
                    .put("packageName", pkg)
                    .put("label", label)
                    .put("isSystem", isSystem)
            )
        }
        val sorted = rows.sortedWith(
            compareBy({ it.optString("label").lowercase() }, { it.optString("packageName") })
        )
        val out = JSONArray()
        sorted.forEach { out.put(it) }
        return out.toString()
    }

    /** 本应用的安装来源 / 版本 / targetSdk 自检信息（JSON 字符串）。 */
    private fun selfInstallInfo(): String {
        val pm = context.packageManager
        val pkg = context.packageName
        val obj = JSONObject()
        try {
            val info = pm.getPackageInfo(pkg, 0)
            val flags = info.applicationInfo?.flags ?: 0
            val installer = runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(pkg).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkg)
                }
            }.getOrNull()
            obj.put("packageName", pkg)
            obj.put("versionName", info.versionName ?: "")
            obj.put(
                "versionCode",
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    info.longVersionCode
                } else {
                    @Suppress("DEPRECATION")
                    info.versionCode.toLong()
                }
            )
            obj.put("targetSdk", info.applicationInfo?.targetSdkVersion ?: 0)
            obj.put("isSystem", (flags and ApplicationInfo.FLAG_SYSTEM) != 0)
            obj.put("isDebuggable", (flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0)
            obj.put("installerPackage", installer ?: "")
            obj.put("firstInstallTime", info.firstInstallTime)
            obj.put("lastUpdateTime", info.lastUpdateTime)
            obj.put("sdkInt", Build.VERSION.SDK_INT)
        } catch (t: Throwable) {
            obj.put("error", t.message ?: t.toString())
        }
        return obj.toString()
    }
}
