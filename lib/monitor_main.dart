import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:is_it_enough/features/monitoring/data/foreground_monitor.dart';
import 'package:is_it_enough/features/monitoring/data/usage_stats_method_channel.dart';
import 'package:is_it_enough/features/reminder/reminder_controller.dart';
import 'package:is_it_enough/features/settings/data/repositories/settings_repository.dart';
import 'package:is_it_enough/features/settings/data/repositories/statistics_repository.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';
import 'package:is_it_enough/shared/services/notification_service.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:is_it_enough/shared/services/statistics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局持有控制器，避免被 GC 回收（其内部定时器需要持续存活）。
ReminderController? _headlessController;

/// 无界面（headless）监控入口。
///
/// 由原生 `MonitorForegroundService` 在“App 界面不存在”时拉起：
/// - 开机自启（BOOT_COMPLETED）之后；
/// - App 进程被系统回收、前台服务被重新创建之后。
///
/// 与 `main()` 的差别：不调用 runApp（此时没有 FlutterView），
/// 只初始化配置/统计/通知并启动轮询。App 界面一旦创建，原生侧会销毁本引擎，
/// 由界面侧的 `main()` 接管，避免两个引擎同时轮询导致重复提醒。
@pragma('vm:entry-point')
Future<void> monitorMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb || !Platform.isAndroid) return;

  final logger = LoggerService();
  logger.info('后台监控引擎启动（无界面）', tag: 'MonitorService');

  final prefs = await SharedPreferences.getInstance();
  final settingsService = SettingsService(SettingsRepository(prefs));
  await settingsService.load();
  logger.debugMode = settingsService.debugMode;

  final statsService = StatisticsService(StatisticsRepository(prefs));
  await statsService.load();

  // 无 Activity：只初始化通知通道，不发起运行时权限弹窗。
  await NotificationReminderService().init(requestPermission: false);

  final monitor = ForegroundMonitor(
    usageStats: UsageStatsMethodChannel(),
    settingsService: settingsService,
    onTrigger: (event) {
      logger.info('触发提醒: $event', tag: 'Monitor');
      statsService.recordTrigger();
      _headlessController?.handleTrigger(event);
    },
  );

  final controller = ReminderController(
    monitor: monitor,
    settings: settingsService,
    statistics: statsService,
  );

  // Overlay 中“再刷/现在放下”的回传（若 Overlay 能在本引擎中拉起）。
  try {
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) controller.onOverlayAction(data);
    });
  } catch (e) {
    debugPrint('[够了吗] headless Overlay listener 注册失败: $e');
  }

  _headlessController = controller;
  monitor.start();

  logger.info(
    '后台监控已启动（无界面），阈值=${settingsService.thresholdMinutes}分钟，'
    '开关=${settingsService.monitoringEnabled}',
    tag: 'MonitorService',
  );
}
