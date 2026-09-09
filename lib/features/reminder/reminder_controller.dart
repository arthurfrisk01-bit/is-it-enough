import 'dart:async';
import 'dart:convert';
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
import 'package:is_it_enough/features/reminder/reminder_overlay_channel.dart';
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
/// 2026-09-09 实机结论：系统通知的“全屏 Intent”在屏幕点亮/解锁时会被系统
/// 降级成横幅（AOSP 文档明确行为），所以“前台全屏”只能靠悬浮窗实现。旧的
/// 独立 Flutter 引擎悬浮窗在实机上从不回执（只弹通知、没有全屏），已改为
/// 原生 WindowManager 窗口（见 `ReminderOverlay.kt`）：
///
/// 1. 先发系统通知 —— 唯一由系统保证送达的通道，锁屏时还会拉起全屏 Intent；
/// 2. 有悬浮窗权限且未锁屏 → 原生全屏悬浮窗盖在当前应用之上，成功即撤回通知；
/// 3. 悬浮窗不可用 → 退回 App 内提醒页；每一步成败都写入应用日志页。
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

  /// Android 呈现链路：系统通知（兜底必达）+ 原生全屏悬浮窗。
  ///
  /// 系统通知的全屏 Intent 在屏幕点亮/解锁时会被系统降级成横幅，因此“前台
  /// 全屏”只能由悬浮窗完成。原生窗口的 `show()` 同步返回窗口是否真的挂上，
  /// 不再需要回执/超时/补发那一套握手。
  Future<void> _showAndroidReminder({
    required ReminderMode mode,
    required String packageName,
    required String appLabel,
    required int snoozeMinutes,
    required int continuousMinutes,
  }) async {
    // 1) 系统通知先发。它是唯一由系统保证送达的通道（锁屏时还会直接拉起全屏
    //    Intent），先发出去，即使悬浮窗被 ROM 拦截，用户也一定收到提醒。
    _logger.info('发送系统通知（兜底必达通道）', tag: 'Reminder');
    final notificationSent = await _sendNotificationSafely(
      mode,
      continuousMinutes,
      appLabel,
    );

    // 2) 原生悬浮窗盖在任意应用之上，这才是“前台全屏”。
    var overlayOk = false;
    var granted = false;
    if (!kIsWeb && Platform.isAndroid) {
      granted = await ReminderOverlayChannel.isPermissionGranted();
      _logger.info('悬浮窗权限: $granted', tag: 'Reminder');
      if (granted) {
        overlayOk = await ReminderOverlayChannel.show(
          mode: mode.storageKey,
          appName: appLabel,
          snoozeMinutes: snoozeMinutes,
          continuousMinutes: continuousMinutes,
        );
        _logger.info('原生悬浮窗显示结果: $overlayOk', tag: 'Reminder');
      }
    }

    if (overlayOk) {
      // 悬浮窗已经盖住屏幕，撤掉通知避免双份打扰（提示音已经响过）。
      _logger.info('悬浮窗已覆盖屏幕，撤回通知避免重复提醒', tag: 'Reminder');
      await NotificationReminderService().cancelReminder();
      return;
    }

    // 3) 悬浮窗不可用（无权限 / 锁屏 / 被系统拦截）：退回 App 内提醒页。
    _logger.warning(
      '悬浮窗未生效（权限=$granted，锁屏或系统拦截），'
      '${notificationSent ? "已发送通知" : "通知失败"}，尝试打开 App 内提醒',
      tag: 'Reminder',
    );
    final appPageOpened = _openInAppReminder(mode, appLabel, snoozeMinutes);

    // 如果所有提醒通道都失败，强制记录严重错误
    if (!notificationSent && !appPageOpened) {
      _logger.fatal(
        '所有提醒通道失败：通知=$notificationSent, 悬浮窗权限=$granted, App内页=$appPageOpened',
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

  /// 原生悬浮窗按钮回传的用户操作。
  Future<void> onOverlayAction(Map<dynamic, dynamic> data) async {
    final action = data['action'] as String?;
    switch (action) {
      case 'snooze':
        await snooze();
        break;
      case 'putDown':
        await putDown();
        break;
      default:
        _logger.debug('悬浮窗操作: $action', tag: 'Reminder');
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
    await ReminderOverlayChannel.hide();
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
    await ReminderOverlayChannel.hide();
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

  /// 解析通知 payload 并打开完整的 App 内提醒页。
  ///
  /// payload 由 [NotificationReminderService.showReminder] 写入（JSON）。
  void openReminderFromNotificationPayload(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is! Map) return;
      if (data['type'] != 'reminder') return;
      openReminderFromNotification(
        mode: ReminderMode.fromStorage(data['mode'] as String?),
        appName: data['appName'] as String? ?? '这个应用',
      );
    } catch (e) {
      _logger.warning('解析通知 payload 失败: $e', tag: 'Reminder');
    }
  }

  /// 用户点击提醒通知时，打开完整的 App 内提醒页。
  ///
  /// 通知是最可靠的送达通道，锁屏时系统还会直接拉起全屏 Intent；用户点它
  /// 说明想看提醒，这里直接进入提醒界面，而不是只打开 App 首页。
  /// 冷启动（点通知拉起 App）时 Navigator 还没挂上，等首帧后再打开。
  void openReminderFromNotification({
    required ReminderMode mode,
    required String appName,
  }) {
    final minutes = _snoozeMinutes;
    if (appNavigatorKey.currentState != null) {
      _openInAppReminder(mode, appName, minutes);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInAppReminder(mode, appName, minutes);
    });
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
