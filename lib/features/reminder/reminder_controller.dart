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
import 'package:is_it_enough/shared/services/settings_service.dart';

/// 提醒控制器：把 [ForegroundMonitor] 的触发事件转为用户可见的提醒。
///
/// 职责：
/// - 根据设置页的“弱提醒/强提醒”选择呈现方式；
/// - 维护“再刷 5 分钟 -> 连续 3 次后缩为 2 分钟”的计数逻辑；
/// - 点击“现在放下”后进入呼吸引导页。
class ReminderController {
  ReminderController({
    required ForegroundMonitor monitor,
    required SettingsService settings,
  })  : _monitor = monitor,
        _settings = settings;

  final ForegroundMonitor _monitor;
  final SettingsService _settings;

  String? _activePackage;
  bool _showing = false;
  int _snoozeCount = 0;

  /// 当前是否正在展示提醒。
  bool get isShowing => _showing;

  /// 监听器触发时调用。
  Future<void> handleTrigger(MonitorTriggerEvent event) async {
    if (_showing && _activePackage == event.packageName) {
      // 同一会话已经展示，避免重复弹窗。
      return;
    }

    _activePackage = event.packageName;
    _snoozeCount = 0;
    _showing = true;

    final mode = _settings.reminderMode;
    final minutes = _snoozeMinutes;

    // Android + 有悬浮窗权限 -> 全局 Overlay。
    // 其余情况（iOS / 未授权 / 桌面预览）回退到 App 内全屏/顶部页面。
    if (!kIsWeb && Platform.isAndroid &&
        await OverlayWindowService.isPermissionGranted()) {
      await OverlayWindowService.sendReminderData(
        mode: mode.storageKey,
        packageName: event.packageName,
        snoozeMinutes: minutes,
      );
      await OverlayWindowService.show();
    } else {
      _openInAppReminder(mode, event.packageName, minutes);
    }
  }

  /// Overlay 子窗口通过 shareData 把用户操作回传主 App。
  Future<void> onOverlayAction(Map<dynamic, dynamic> data) async {
    final action = data['action'] as String?;
    debugPrint('[够了吗] Overlay action: $action, data: $data');
    switch (action) {
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
    if (!_showing) return;

    _snoozeCount += 1;
    final minutes = _snoozeMinutes;

    _showing = false;
    await OverlayWindowService.hide();

    _monitor.snooze(Duration(minutes: minutes));
    debugPrint('[够了吗] 再刷 $minutes 分钟（累计 $_snoozeCount 次）');
  }

  /// 点击“现在放下”。
  Future<void> putDown() async {
    if (!_showing) return;

    _showing = false;
    await OverlayWindowService.hide();
    _monitor.resetSession();

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
  int get _snoozeMinutes {
    return _snoozeCount >= AppConstants.maxSnoozeCount
        ? AppConstants.shortenedSnoozeMinutes
        : 5;
  }

  void _openInAppReminder(
    ReminderMode mode,
    String packageName,
    int minutes,
  ) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[够了吗] 无法打开 App 内提醒：当前没有 Navigator');
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: mode == ReminderMode.strong,
        builder: (_) => InAppReminderPage(
          mode: mode,
          packageName: packageName,
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
  }
}
