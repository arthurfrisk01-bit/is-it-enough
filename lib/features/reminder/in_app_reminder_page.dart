import 'package:flutter/material.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/features/reminder/strong_reminder_view.dart';
import 'package:is_it_enough/features/reminder/weak_reminder_view.dart';

/// App 内提醒页（无全局悬浮窗权限时的回退方案）。
///
/// - 强提醒：全屏毛玻璃阻断；
/// - 弱提醒：顶部轻量悬浮卡片，不遮挡整屏。
class InAppReminderPage extends StatelessWidget {
  const InAppReminderPage({
    super.key,
    required this.mode,
    required this.packageName,
    required this.snoozeMinutes,
    required this.onSnooze,
    required this.onPutDown,
  });

  final ReminderMode mode;
  final String packageName;
  final int snoozeMinutes;
  final VoidCallback onSnooze;
  final VoidCallback onPutDown;

  @override
  Widget build(BuildContext context) {
    if (mode == ReminderMode.strong) {
      return StrongReminderView(
        packageName: packageName,
        snoozeMinutes: snoozeMinutes,
        onSnooze: onSnooze,
        onPutDown: onPutDown,
      );
    }

    // 弱提醒：透明背景 + 顶部卡片。
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: WeakReminderView(
              packageName: packageName,
              snoozeMinutes: snoozeMinutes,
              onSnooze: onSnooze,
              onPutDown: onPutDown,
              onClose: onSnooze,
            ),
          ),
        ),
      ),
    );
  }
}
