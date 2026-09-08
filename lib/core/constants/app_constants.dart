import 'reminder_modes.dart';

/// 全局常量。
class AppConstants {
  AppConstants._();

  /// 应用展示名称。
  static const String appName = '够了吗';

  /// Android 侧后台监听轮询间隔。
  static const Duration usagePollInterval = Duration(seconds: 5);

  /// 默认触发阈值。
  static const int defaultThresholdMinutes = 10;

  /// 可选的触发阈值（分钟）。
  static const List<int> thresholdOptions = [5, 10, 15, 20];

  /// “再刷 5 分钟”连续点击次数上限。
  static const int maxSnoozeCount = 3;

  /// 超过 [maxSnoozeCount] 次后，自动缩短为“再刷 2 分钟”。
  static const int shortenedSnoozeMinutes = 2;

  /// 弱/强提醒默认模式。
  static const ReminderMode defaultReminderMode = ReminderMode.strong;
}
