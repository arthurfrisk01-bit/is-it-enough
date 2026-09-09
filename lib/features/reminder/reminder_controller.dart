import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/core/navigation/app_navigator.dart';
import 'package:is_it_enough/features/breathing/breathing_page.dart';
import 'package:is_it_enough/features/monitoring/data/foreground_monitor.dart';
import 'package:is_it_enough/features/monitoring/domain/monitor_trigger_event.dart';
import 'package:is_it_enough/features/reminder/in_app_reminder_page.dart';
import 'package:is_it_enough/features/reminder/overlay_window_service.dart';
import 'package:is_it_enough/shared/services/notification_service.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:is_it_enough/shared/services/statistics_service.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';

/// 提醒控制器：把 [ForegroundMonitor] 的触发事件转为用户可见的提醒。
///
/// 职责：
/// - 根据设置页的“弱提醒/强提醒”选择呈现方式；
/// - 维护“再刷 5 分钟 -> 连续 3 次后缩为 2 分钟”的计数逻辑；
/// - 点击“现在放下”后进入呼吸引导页。
///
/// ## 呈现链路（按优先级，全部失败也有兜底）
///
/// Overlay 服务只能在“触发那一刻”从后台拉起，Android 12+ / 国产 ROM 可能
/// 静默丢弃，导致历史版本“日志有触发、用户无提醒”。因此这里不再只赌
/// Overlay 一条路：
///
/// 1. 有悬浮窗权限 → 先尝试 Overlay，600ms 后用 `isOverlayActive` 复核；
/// 2. Overlay 未授权或启动失败 → 立即打开 App 内提醒页 + 发一条系统通知
///    （强提醒=全屏 intent，弱提醒=Heads-up，后台必达）；
/// 3. 每一步的成败都写入应用日志页，方便定位。
class ReminderController {
  ReminderController({
    required ForegroundMonitor monitor,
    required SettingsService settings,
    required StatisticsService statistics,
  })  : _monitor = monitor,
        _settings = settings,
        _statistics = statistics;

  final ForegroundMonitor _monitor;
  final SettingsService _settings;
  final StatisticsService _statistics;
  final _logger = LoggerService();

  String? _activePackage;
  int _snoozeCount = 0;

  /// 上一次触发提醒的应用包名，用于界定“同一轮连续使用”。
  String? _lastTriggerPackage;

  /// 当前是否正在展示提醒（用于统计，未用于拦截）。
  bool get isShowing => _activePackage != null;

  /// Overlay 渲染完成回执；只有它被 complete 才认为悬浮窗真的出现了。
  Completer<void>? _overlayAck;

  /// 监听器触发时调用。
  Future<void> handleTrigger(MonitorTriggerEvent event) async {
    // 注意：不再使用 _showing 标志阻止重复提醒。
    // 原有逻辑在 Overlay/App内页被用户手动关闭（不点按钮）时会导致
    // _showing 永远为 true，后续提醒全被静默拦截。
    // 改由 ForegroundMonitor 的 _sessionTriggered 标志控制同一会话的重复提醒。

    // “连续再刷”计数只在同一应用的一轮连续使用内累加：换到别的应用
    // （或用户点“现在放下”）视为新一轮，计数归零。
    // 旧实现在每次触发时无条件清零，导致 _snoozeCount 永远到不了
    // maxSnoozeCount，“连续再刷 3 次后缩短为 2 分钟”的规则从未生效。
    if (event.packageName != _lastTriggerPackage) {
      _snoozeCount = 0;
      _lastTriggerPackage = event.packageName;
    }

    _activePackage = event.packageName;

    final mode = _settings.reminderMode;
    final minutes = _snoozeMinutes;
    final continuousMinutes = (event.continuousSeconds / 60).ceil();
    final appLabel = event.appLabel ?? event.packageName;
    
    _logger.info(
      '处理触发提醒 $appLabel (${event.packageName})，'
      'mode=${mode.storageKey}，已连续使用 $continuousMinutes 分钟',
      tag: 'Reminder',
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _showAndroidReminder(
        mode: mode,
        packageName: event.packageName,
        appLabel: appLabel,
        snoozeMinutes: minutes,
        continuousMinutes: continuousMinutes,
      );
    } else {
      // iOS / 桌面预览：直接 App 内提醒（无后台 Overlay 概念）。
      _openInAppReminder(mode, appLabel, minutes);
    }
  }

  /// Android 呈现链路：Overlay → 失败则 通知 + App 内页。
  Future<void> _showAndroidReminder({
    required ReminderMode mode,
    required String packageName,
    required String appLabel,
    required int snoozeMinutes,
    required int continuousMinutes,
  }) async {
    var overlayOk = false;

    final granted = await OverlayWindowService.isPermissionGranted();
    _logger.info('悬浮窗权限: $granted', tag: 'Reminder');

    if (granted) {
      try {
        // 先拉起服务，再送数据：Overlay 引擎未就绪时 shareData 会被直接丢弃，
        // 旧实现先送数据后 show，导致悬浮窗里只剩占位符（用户以为“没提醒”）。
        await OverlayWindowService.show();
        _overlayAck = Completer<void>();
        await Future<void>.delayed(const Duration(milliseconds: 400));

        Future<void> pushData() => OverlayWindowService.sendReminderData(
              mode: mode.storageKey,
              packageName: packageName,
              appName: appLabel,
              snoozeMinutes: snoozeMinutes,
            );
        await pushData();

        var overlayAcked = false;
        try {
          await _overlayAck!.future.timeout(const Duration(milliseconds: 1200));
          overlayAcked = true;
        } on TimeoutException {
          overlayAcked = false;
        }

        if (!overlayAcked) {
          _logger.warning('Overlay 未回执渲染完成，补送一次提醒数据', tag: 'Reminder');
          await pushData();
          await Future<void>.delayed(const Duration(milliseconds: 500));
          overlayAcked = _overlayAck!.isCompleted;
        }

        // isActive() 只反映 OverlayService 是否在跑（插件里是静态布尔），
        // 服务在跑 ≠ 窗口真的画出来了，必须叠加“渲染完成回执”才敢认定成功。
        final serviceRunning = await OverlayWindowService.isActive();
        overlayOk = overlayAcked && serviceRunning;
        _logger.info(
          'Overlay 复核：渲染回执=$overlayAcked 服务运行中=$serviceRunning → 视为已显示=$overlayOk',
          tag: 'Reminder',
        );
      } catch (e) {
        _logger.error('Overlay 展示异常: $e', tag: 'Reminder');
        overlayOk = false;
      }
    }

    // 系统通知是兜底必达通道，始终发送；但 Overlay 已经显示时降级为静默
    // （不响铃、不震动、不弹全屏），避免悬浮窗 + 通知 + 震动三重叠的重复打扰。
    _logger.info(
      '系统通知策略：${overlayOk ? "悬浮窗已确认显示 → 静默通知（仅留存）" : "悬浮窗未确认 → 完整通知（响铃+横幅/全屏）"}',
      tag: 'Reminder',
    );
    final notificationSent = await _sendNotificationSafely(
      mode,
      continuousMinutes,
      appLabel,
      silent: overlayOk,
    );

    if (overlayOk) {
      _logger.info('Overlay 已显示（${notificationSent ? "通知已发送" : "通知失败"}）', tag: 'Reminder');
      return;
    }

    // Overlay 不可用（无权限 / 被系统拦截）：打开 App 内页作为备用。
    _logger.warning(
      'Overlay 未生效（权限=$granted），${notificationSent ? "已发送通知" : "通知失败"}，尝试打开 App 内提醒',
      tag: 'Reminder',
    );
    final appPageOpened = _openInAppReminder(mode, appLabel, snoozeMinutes);
    
    // 如果所有提醒通道都失败，强制记录严重错误
    if (!notificationSent && !appPageOpened) {
      _logger.fatal(
        '所有提醒通道失败：通知=$notificationSent, Overlay=$granted, App内页=$appPageOpened',
        tag: 'Reminder',
      );
    }
  }

  /// 安全发送系统通知，捕获所有异常并返回是否成功。
  ///
  /// [silent] 为 true 时只留一条静默通知（不响铃/不震动/不弹全屏），
  /// 用于 Overlay 已成功展示的场景。
  Future<bool> _sendNotificationSafely(
    ReminderMode mode,
    int continuousMinutes,
    String appLabel, {
    bool silent = false,
  }) async {
    try {
      return await NotificationReminderService().showReminder(
        mode: mode,
        continuousMinutes: continuousMinutes,
        appLabel: appLabel,
        silent: silent,
      );
    } catch (e) {
      _logger.error('发送系统通知失败: $e', tag: 'Reminder');
      return false;
    }
  }

  /// Overlay 子窗口通过 shareData 把用户操作回传主 App。
  Future<void> onOverlayAction(Map<dynamic, dynamic> data) async {
    final action = data['action'] as String?;
    _logger.info('Overlay action: $action', tag: 'Reminder');
    switch (action) {
      case 'overlayShown':
        // Overlay 内容真正渲染完成的回执：只有收到它才允许把系统通知降级为静默。
        if (_overlayAck != null && !_overlayAck!.isCompleted) {
          _overlayAck!.complete();
        }
        break;
      case 'snooze':
        await snooze();
        break;
      case 'putDown':
        await putDown();
        break;
      default:
        break;
    }
  }

  /// 点击“再刷 X 分钟”。
  Future<void> snooze() async {
    if (_activePackage == null) return;

    // 先按“当前累计次数”决定本次时长，再累加：
    // 第 1~3 次再刷仍是 5 分钟，第 4 次起缩短为 2 分钟（PRD）。
    final minutes = _snoozeMinutes;
    _snoozeCount += 1;

    _activePackage = null;
    await OverlayWindowService.hide();
    await NotificationReminderService().cancelReminder();

    // 调试模式特殊处理：30秒后再次提醒
    final snoozeDuration = _settings.debugMode 
        ? const Duration(seconds: 30)
        : Duration(minutes: minutes);
    
    _monitor.snooze(snoozeDuration);
    await _statistics.recordContinue();
    
    final displayTime = _settings.debugMode ? '30 秒' : '$minutes 分钟';
    _logger.info('再刷 $displayTime（累计 $_snoozeCount 次）', tag: 'Reminder');
  }

  /// 点击“现在放下”。
  Future<void> putDown() async {
    if (_activePackage == null) return;

    _activePackage = null;
    // 用户已放下：这一轮连续使用结束，“再刷”计数归零。
    _snoozeCount = 0;
    _lastTriggerPackage = null;
    await OverlayWindowService.hide();
    await NotificationReminderService().cancelReminder();
    _monitor.resetSession();

    await _statistics.recordPutDown();
    _logger.info('现在放下', tag: 'Reminder');

    // 打开全屏黑色呼吸引导页。
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const BreathingPage(),
      ),
    );
  }

  /// 计算本次“再刷”分钟数。
  ///
  /// PRD：连续选择 > 3 次后，第 4 次起自动缩短为 2 分钟。
  /// 计数由 [handleTrigger] 按应用维护、[putDown] 归零，见 [_snoozeCount]。
  /// 调试模式下自动缩短为 30 秒（0.5 分钟）。
  int get _snoozeMinutes {
    // 调试模式：30 秒后再次提醒
    if (_settings.debugMode) return 0;  // Duration(minutes: 0) 会被特殊处理为30秒
    
    // 正常模式：5分钟或2分钟
    return _snoozeCount >= AppConstants.maxSnoozeCount
        ? AppConstants.shortenedSnoozeMinutes
        : 5;
  }

  bool _openInAppReminder(
    ReminderMode mode,
    String appName,
    int minutes,
  ) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _logger.warning('无法打开 App 内提醒：当前没有 Navigator', tag: 'Reminder');
      return false;
    }

    navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: mode == ReminderMode.strong,
        builder: (_) => InAppReminderPage(
          mode: mode,
          appName: appName,
          snoozeMinutes: minutes,
          onSnooze: () {
            navigator.pop();
            unawaited(snooze());
          },
          onPutDown: () {
            navigator.pop();
            unawaited(putDown());
          },
        ),
      ),
    );
    return true;
  }
}
