import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:is_it_enough/app.dart';
import 'package:is_it_enough/features/monitoring/data/foreground_monitor.dart';
import 'package:is_it_enough/features/monitoring/data/monitor_service_channel.dart';

// monitor_main.dart 定义了原生后台服务使用的无界面入口 `monitorMain`，
// 同样必须 export 才能在 Release(AOT) 中保留。
export 'monitor_main.dart';
import 'package:is_it_enough/features/monitoring/data/usage_stats_method_channel.dart';
import 'package:is_it_enough/features/reminder/reminder_controller.dart';
import 'package:is_it_enough/features/reminder/reminder_overlay_channel.dart';
import 'package:is_it_enough/features/settings/data/repositories/settings_repository.dart';
import 'package:is_it_enough/features/settings/data/repositories/statistics_repository.dart';
import 'package:is_it_enough/shared/services/notification_service.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:is_it_enough/shared/services/statistics_service.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LoggerService.isolateName = 'UI';
  LoggerService.installErrorHandlers();

  // 初始化本地配置。
  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(SettingsRepository(prefs));
  await settingsService.load();

  // 初始化统计服务。
  final statsService = StatisticsService(StatisticsRepository(prefs));
  await statsService.load();

  // 全局日志服务单例。
  final logger = LoggerService();
  logger.debugMode = settingsService.debugMode;
  logger.info('应用启动', tag: 'Main');

  // 初始化系统通知通道（悬浮窗不可用时的兜底提醒通道）。
  // 先挂点击回调再 init：冷启动（点通知拉起 App）时回执会在 init 里就回调，
  // 那时控制器还没建好，先把 payload 暂存，等监听器就绪后再打开提醒页。
  NotificationReminderService.onNotificationTap = _handleNotificationTap;
  await NotificationReminderService().init();

  // Android：启动前台应用轮询监听。
  // iOS：按 PRD 不启用后台监听,只保留"用户主动开启计时器"模式。
  if (!kIsWeb && Platform.isAndroid) {
    _startAndroidMonitor(settingsService, statsService);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider.value(value: statsService),
        ChangeNotifierProvider.value(value: logger),
      ],
      child: const IsItEnoughApp(),
    ),
  );
}

/// 全局持有 Android 监听器，避免被 GC 回收。
// ignore: unused_element
ForegroundMonitor? _androidMonitor;

/// 全局提醒控制器。
ReminderController? _reminderController;

/// 冷启动（点通知拉起 App）时暂存的通知 payload，等控制器就绪后再打开提醒页。
String? _pendingNotificationPayload;

/// 通知被点击：悬浮窗不可用时它是唯一的全屏入口（锁屏时系统还会直接拉起全屏 Intent）。
void _handleNotificationTap(String? payload) {
  if (payload == null || payload.isEmpty) return;
  final controller = _reminderController;
  if (controller == null) {
    _pendingNotificationPayload = payload;
    return;
  }
  controller.openReminderFromNotificationPayload(payload);
}

/// 启动 Android 5 秒轮询监听,并把触发事件交给提醒控制器。
void _startAndroidMonitor(SettingsService settingsService, StatisticsService statsService) {
  final logger = LoggerService();
  logger.info('启动 Android 监听器', tag: 'Main');
  
  final monitor = ForegroundMonitor(
    usageStats: UsageStatsMethodChannel(),
    settingsService: settingsService,
    onTrigger: (event) {
      logger.info('触发提醒: $event', tag: 'Monitor');
      statsService.recordTrigger(packageName: event.packageName);
      // 提醒控制器会按设置模式展示 Overlay 或 App 内提醒。
      _reminderController?.handleTrigger(event);
    },
  );

  final controller = ReminderController(
    monitor: monitor,
    settings: settingsService,
    statistics: statsService,
  );

  // 接收原生悬浮窗按钮（再刷/现在放下）的回传。
  ReminderOverlayChannel.setActionHandler(
    (action) => controller.onOverlayAction({'action': action}),
  );

  _androidMonitor = monitor;
  _reminderController = controller;

  // 冷启动时通知回执可能早于控制器创建，这里补一次。
  final pending = _pendingNotificationPayload;
  if (pending != null) {
    _pendingNotificationPayload = null;
    controller.openReminderFromNotificationPayload(pending);
  }

  monitor.start();

  // 保活服务：把进程提升为前台优先级；App 进程被系统回收后由它拉起
  // headless 引擎（monitor_main.dart 的 monitorMain）继续监控。
  unawaited(_syncMonitoringService(settingsService));
  settingsService.addListener(() => unawaited(_syncMonitoringService(settingsService)));

  // 监听 debugMode 变化，同步到 LoggerService
  settingsService.addListener(() {
    LoggerService().debugMode = settingsService.debugMode;
  });
  
  logger.info('Android UsageStats 轮询已启动，阈值=${settingsService.thresholdMinutes}分钟', tag: 'Main');
  debugPrint('[够了吗] Android UsageStats 轮询已启动，阈值=${settingsService.thresholdMinutes}分钟，监听=${settingsService.monitoringEnabled}');
}

/// 上次同步给原生保活服务的运行状态，避免每次设置变化都重复调用通道。
bool? _monitorServiceRunning;

/// 按“后台监控”开关启动/停止原生保活服务。
Future<void> _syncMonitoringService(SettingsService settings) async {
  final shouldRun = settings.monitoringEnabled;
  if (_monitorServiceRunning == shouldRun) return;
  _monitorServiceRunning = shouldRun;
  if (shouldRun) {
    await MonitorServiceChannel.start();
  } else {
    await MonitorServiceChannel.stop();
  }
}
