import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';

/// 系统通知提醒服务（兜底通道）。
///
/// 悬浮窗 Overlay 依赖“后台启动前台服务”，在 Android 12+ / 国产 ROM 上可能被
/// 系统静默丢弃（触发后无任何可见结果）。系统通知不依赖后台服务启动，任何
/// 场景都能送达，因此作为提醒的**必发兜底通道**：
/// - 强提醒：高优先级 + 全屏 Intent（点亮屏幕直接打断，权限允许时）；
/// - 弱提醒：高优先级 Heads-up 横幅。
///
/// 该服务只在主 App 入口初始化；Overlay 子引擎不需要。
class NotificationReminderService {
  factory NotificationReminderService() => _instance;

  NotificationReminderService._();

  static final NotificationReminderService _instance =
      NotificationReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const int _reminderNotificationId = 1001;
  static const String _strongChannelId = 'reminder_strong';
  static const String _weakChannelId = 'reminder_soft';

  /// 初始化通知通道（幂等）。App 启动时调用一次。
  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
      );
      await _plugin.initialize(settings);

      // Android 13+ 需要运行时通知权限；此处只发起一次系统弹窗，不阻塞启动。
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();

      _initialized = true;
      LoggerService().info('通知服务已初始化', tag: 'Notification');
    } catch (e) {
      LoggerService().error('通知服务初始化失败: $e', tag: 'Notification');
    }
  }

  /// 触发提醒时调用：无论悬浮窗是否可用，都补发一条系统通知。
  Future<void> showReminder({
    required ReminderMode mode,
    required int continuousMinutes,
  }) async {
    if (!_initialized) return;
    if (kIsWeb || !Platform.isAndroid) return;

    final logger = LoggerService();
    final strong = mode == ReminderMode.strong;

    try {
      final details = AndroidNotificationDetails(
        strong ? _strongChannelId : _weakChannelId,
        strong ? '强提醒（全屏）' : '弱提醒',
        channelDescription: strong ? '全屏打断提醒' : '轻提醒横幅',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        fullScreenIntent: strong,
        onlyAlertOnce: true,
        autoCancel: true,
      );

      await _plugin.show(
        _reminderNotificationId,
        strong ? '够了吗：先放下手机' : '够了吗：该休息一下了',
        strong
            ? '你已经连续刷了 $continuousMinutes 分钟。深呼吸，把手机放下片刻。'
            : '连续使用时间不短了，注意让眼睛和脖子歇一歇。',
        NotificationDetails(android: details),
        payload: 'reminder',
      );
      logger.info('系统通知已发送（${strong ? "强" : "弱"}）', tag: 'Notification');
    } catch (e) {
      logger.error('发送系统通知失败: $e', tag: 'Notification');
    }
  }

  /// 用户在提醒上做出“再刷/放下”操作后调用，移除残留通知。
  Future<void> cancelReminder() async {
    if (!_initialized || kIsWeb || !Platform.isAndroid) return;
    try {
      await _plugin.cancel(_reminderNotificationId);
    } catch (e) {
      LoggerService().debug('取消通知失败: $e', tag: 'Notification');
    }
  }
}
