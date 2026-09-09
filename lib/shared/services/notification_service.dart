import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';

/// 系统通知提醒服务（兜底通道）。
///
/// 悬浮窗 Overlay 依赖“后台启动前台服务”，在 Android 12+ / 国产 ROM 上可能被
/// 系统静默丢弃（触发后无任何可见结果）。系统通知不依赖后台服务启动，任何
/// 场景都能送达，因此作为提醒的**必发兜底通道**：
/// - 强提醒：高优先级 + 全屏 Intent（点亮屏幕直接打断，权限允许时）；
/// - 弱提醒：高优先级 Heads-up 横幅；
/// - 静默模式：Overlay 已成功展示时只留一条低优先级通知，不响铃不震动。
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
  static const String _silentChannelId = 'reminder_silent';

  /// 与 MainActivity 的原生诊断通道通信（全屏 Intent 可用性探测）。
  static const MethodChannel _diagnosisChannel =
      MethodChannel('com.isitenough.app/diagnosis');

  /// 初始化通知通道（幂等）。App 启动时调用一次。
  ///
  /// [requestPermission] 为 false 时不发起 Android 13+ 的运行时通知权限弹窗：
  /// 无界面的后台引擎没有 Activity，调用它只会失败并留下误导性日志。
  Future<void> init({bool requestPermission = true}) async {
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
      if (requestPermission) {
        final granted = await androidImpl?.requestNotificationsPermission();
        LoggerService().debug('运行时通知权限请求结果: $granted', tag: 'Notification');
      }

      _initialized = true;
      var enabledText = '未知';
      try {
        final enabled = await androidImpl?.areNotificationsEnabled();
        enabledText = enabled == null ? '未知' : '$enabled';
      } catch (e) {
        enabledText = '探测失败($e)';
      }
      LoggerService()
          .info('通知服务已初始化（系统通知总开关: $enabledText）', tag: 'Notification');
    } catch (e) {
      LoggerService().error('通知服务初始化失败: $e', tag: 'Notification');
    }
  }

  /// 触发提醒时调用：无论悬浮窗是否可用，都补发一条系统通知。
  ///
  /// [silent] 为 true 时走低优先级静默通道（不响铃、不震动、不弹全屏），
  /// 用于 Overlay 已经成功展示、通知仅作通知栏留存的场景，避免三重叠打扰。
  ///
  /// 返回是否成功发送（用于上层判断兜底策略）。
  Future<bool> showReminder({
    required ReminderMode mode,
    required int continuousMinutes,
    required String appLabel,
    bool silent = false,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;

    final logger = LoggerService();

    // 如果未初始化，尝试紧急初始化一次
    if (!_initialized) {
      logger.warning('通知服务未初始化，尝试紧急初始化', tag: 'Notification');
      await init();
      if (!_initialized) {
        logger.fatal('通知服务紧急初始化失败，无法发送通知', tag: 'Notification');
        return false;
      }
    }

    final strong = mode == ReminderMode.strong;

    // Android 14(API 34)+ 起，非通话/闹钟类应用的“全屏 Intent”默认被系统降级，
    // 需要用户在“系统设置 → 应用 → 通知 → 全屏通知”中手动开启。
    // 这里先探测再决定，避免用户以为强提醒彻底失效。
    var fullScreenIntent = strong && !silent;
    if (fullScreenIntent && !await _canUseFullScreenIntent()) {
      fullScreenIntent = false;
      logger.warning(
        '系统未允许“全屏通知”，强提醒降级为高优先级横幅'
        '（可在 系统设置→应用→通知→全屏通知 中开启）',
        tag: 'Notification',
      );
    }

    try {
      final title = strong ? '够了吗？' : '提醒';
      final body = '你在 $appLabel 上已经使用了 $continuousMinutes 分钟';

      final channelId = silent
          ? _silentChannelId
          : (strong ? _strongChannelId : _weakChannelId);
      logger.info(
        '发送系统通知：通道=$channelId 重要度=${silent ? "low" : "high"} '
        '全屏Intent=$fullScreenIntent 应用=$appLabel 时长=$continuousMinutes分钟',
        tag: 'Notification',
      );

      final details = AndroidNotificationDetails(
        silent
            ? _silentChannelId
            : (strong ? _strongChannelId : _weakChannelId),
        silent ? '提醒留存' : (strong ? '强提醒（全屏打断）' : '弱提醒（轻量提示）'),
        channelDescription: silent
            ? '悬浮窗已提醒，此处仅作留存，不响铃不震动'
            : (strong ? '全屏打断提醒，点亮屏幕' : '轻提醒横幅，不打断操作'),
        importance: silent ? Importance.low : Importance.high,
        priority: silent ? Priority.low : Priority.high,
        category: AndroidNotificationCategory.reminder,
        fullScreenIntent: fullScreenIntent,
        onlyAlertOnce: false, // 每次都提醒，确保不被静音
        autoCancel: true,
        enableVibration: !silent,
        playSound: !silent,
        vibrationPattern: silent
            ? null
            : (strong
                ? Int64List.fromList([0, 500, 200, 500]) // 强提醒震动更强
                : Int64List.fromList([0, 200, 100, 200])), // 弱提醒震动轻柔
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
          summaryText: '数字健康提醒',
        ),
        color: const Color(0xFF9ED8C4),
        ledColor: const Color(0xFF9ED8C4),
        ledOnMs: silent ? 0 : 1000,
        ledOffMs: silent ? 0 : 500,
      );

      await _plugin.show(
        _reminderNotificationId,
        title,
        body,
        NotificationDetails(android: details),
        payload: 'reminder',
      );

      // 回读系统活跃通知，确认通知真的被系统接受（而不是被权限/通道静默丢弃）。
      var posted = false;
      var activeCount = -1;
      try {
        final active = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.getActiveNotifications();
        activeCount = active?.length ?? -1;
        posted = active?.any((n) => n.id == _reminderNotificationId) ?? false;
      } catch (e) {
        logger.debug('回读活跃通知失败: $e', tag: 'Notification');
      }

      logger.info(
        '系统通知已提交（${strong ? "强" : "弱"}${silent ? "·静默" : ""}）'
        '- $appLabel，系统已接受=$posted，活跃通知数=$activeCount',
        tag: 'Notification',
      );
      if (activeCount >= 0 && !posted) {
        logger.fatal(
          '通知已提交但系统未保留 —— 通常是通知权限被拒或该通知通道被设为“关闭”，'
          '请到 系统设置→应用→够了吗→通知 检查',
          tag: 'Notification',
        );
      }
      return true;
    } catch (e) {
      logger.error('发送系统通知失败: $e', tag: 'Notification');
      return false;
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

  /// 探测系统是否允许本应用使用全屏 Intent（Android 14+ 默认只给通话/闹钟）。
  ///
  /// 原生侧不存在该方法或调用异常时返回 true，保持旧系统行为不变。
  Future<bool> _canUseFullScreenIntent() async {
    try {
      final allowed =
          await _diagnosisChannel.invokeMethod<bool>('canUseFullScreenIntent');
      return allowed ?? true;
    } catch (_) {
      return true;
    }
  }
}
