package com.isitenough.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册 UsageStatsManager 的 MethodChannel。
        UsageStatsBridge(flutterEngine, this).register()
    }
}
