import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:is_it_enough/app.dart';
import 'package:is_it_enough/features/monitoring/data/foreground_monitor.dart';

// overlay_main.dart 中定义了 flutter_overlay_window 所需的独立入口 `overlayMain`。
// 通过 export 让该入口随主 library 一起编译，避免 AOT/Release 中被摇树移除。
export 'overlay_main.dart';
import 'package:is_it_enough/features/monitoring/data/usage_stats_method_channel.dart';
import 'package:is_it_enough/features/reminder/reminder_controller.dart';
import 'package:is_it_enough/features/settings/data/repositories/settings_repository.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地配置。
  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(SettingsRepository(prefs));
  await settingsService.load();

  // Android：启动前台应用轮询监听。
  // iOS：按 PRD 不启用后台监听，只保留“用户主动开启计时器”模式。
  if (!kIsWeb && Platform.isAndroid) {
    _startAndroidMonitor(settingsService);
  }

  runApp(
    ChangeNotifierProvider.value(
      value: settingsService,
      child: const IsItEnoughApp(),
    ),
  );
}

/// 全局持有 Android 监听器，避免被 GC 回收。
// ignore: unused_element
ForegroundMonitor? _androidMonitor;

/// 全局提醒控制器。
ReminderController? _reminderController;

/// 启动 Android 5 秒轮询监听，并把触发事件交给提醒控制器。
void _startAndroidMonitor(SettingsService settingsService) {
  final monitor = ForegroundMonitor(
    usageStats: UsageStatsMethodChannel(),
    settingsService: settingsService,
    onTrigger: (event) {
      debugPrint('[够了吗] 触发提醒: $event');
      // 提醒控制器会按设置模式展示 Overlay 或 App 内提醒。
      _reminderController?.handleTrigger(event);
    },
  );

  final controller = ReminderController(
    monitor: monitor,
    settings: settingsService,
  );

  // 接收 Overlay 中用户点击“再刷/现在放下”的回传动作。
  try {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) controller.onOverlayAction(data);
    });
  } catch (e) {
    debugPrint('[够了吗] Overlay listener 注册失败: $e');
  }

  _androidMonitor = monitor;
  _reminderController = controller;
  monitor.start();
  debugPrint('[够了吗] Android UsageStats 轮询已启动');
}
