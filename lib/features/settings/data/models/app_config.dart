import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';

/// 应用配置快照。
///
/// 所有字段均为纯本地配置，不上传任何数据。
class AppConfig {
  const AppConfig({
    this.reminderMode = AppConstants.defaultReminderMode,
    this.thresholdMinutes = AppConstants.defaultThresholdMinutes,
    this.monitoringEnabled = true,
    this.blacklistedPackageNames = const <String>{},
    this.debounceEnabled = true,
  });

  /// 提醒强度：弱 / 强。
  final ReminderMode reminderMode;

  /// 连续使用同一 App 达到该分钟数后触发提醒。
  final int thresholdMinutes;

  /// Android 后台监听总开关。
  final bool monitoringEnabled;

  /// 监控名单：若非空，则只监控这些包名；为空时表示监控所有非白名单应用。
  ///
  /// MVP 先提供“黑名单/名单编辑”的存储结构，后续可扩展为白名单语义。
  final Set<String> blacklistedPackageNames;

  /// 消抖开关：短暂切换其他应用30s内回到原应用继续计算提醒时间。
  final bool debounceEnabled;

  AppConfig copyWith({
    ReminderMode? reminderMode,
    int? thresholdMinutes,
    bool? monitoringEnabled,
    Set<String>? blacklistedPackageNames,
    bool? debounceEnabled,
  }) {
    return AppConfig(
      reminderMode: reminderMode ?? this.reminderMode,
      thresholdMinutes: thresholdMinutes ?? this.thresholdMinutes,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      blacklistedPackageNames:
          blacklistedPackageNames ?? this.blacklistedPackageNames,
      debounceEnabled: debounceEnabled ?? this.debounceEnabled,
    );
  }
}
