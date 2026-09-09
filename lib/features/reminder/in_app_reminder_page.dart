import 'package:flutter/material.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/features/reminder/strong_reminder_view.dart';
import 'package:is_it_enough/features/reminder/weak_reminder_view.dart';

/// App 内提醒页（无全局悬浮窗权限时的回退方案）。
///
/// - 强提醒：全屏毛玻璃阻断；
/// - 弱提醒：顶部轻量悬浮卡片，不遮挡整屏。
///
/// [appName] 是展示给用户的应用名称（如“微信”），由调用方从
/// UsageStats 的 appLabel 取，拿不到时回退为包名。
class InAppReminderPage extends StatelessWidget {
  const InAppReminderPage({
    super.key,
    required this.mode,
    required this.appName,
    required this.snoozeMinutes,
    required this.onSnooze,
    required this.onPutDown,
  });

  final ReminderMode mode;
  final String appName;
  final int snoozeMinutes;
  final VoidCallback onSnooze;
  final VoidCallback onPutDown;

  @override
  Widget build(BuildContext context) {
    if (mode == ReminderMode.strong) {
      return StrongReminderView(
        appName: appName,
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
              appName: appName,
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
