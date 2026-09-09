import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/core/constants/monitor_list_modes.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/features/settings/data/models/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 实现的应用配置读写。
///
/// 使用字符串/布尔/字符串集合存储，字段都有默认值兜底，
/// 避免旧版本或损坏数据导致崩溃。
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kReminderMode = 'reminder_mode';
  static const _kThresholdMinutes = 'threshold_minutes';
  static const _kMonitoringEnabled = 'monitoring_enabled';
  static const _kAutoStartEnabled = 'auto_start_enabled';
  static const _kBlacklistedApps = 'blacklisted_packages';
  static const _kMonitorListMode = 'monitor_list_mode';
  static const _kListPackages = 'monitor_list_packages';
  static const _kScheduleEnabled = 'schedule_enabled';
  static const _kScheduleStart = 'schedule_start_minutes';
  static const _kScheduleEnd = 'schedule_end_minutes';
  static const _kScheduleOutsideMode = 'schedule_outside_mode';
  static const _kDebounceEnabled = 'debounce_enabled';
  static const _kDebugMode = 'debug_mode';
  static const _kFocusSuppressUntil = 'focus_suppress_until';

  /// 读取本地配置；任何字段缺失或非法时使用默认值。
  AppConfig load() {
    final mode = ReminderMode.fromStorage(_prefs.getString(_kReminderMode));
    final storedThreshold = _prefs.getInt(_kThresholdMinutes);
    // 兜底校验：旧版本/手工改过的值可能不在 thresholdOptions 里，
    // 直接透传会让设置页 SegmentedButton 的 selected 与 segments 不匹配而断言崩溃。
    final threshold = AppConstants.thresholdOptions.contains(storedThreshold)
        ? storedThreshold!
        : AppConstants.defaultThresholdMinutes;
    final legacyBlacklist =
        _prefs.getStringList(_kBlacklistedApps)?.toSet() ?? const <String>{};
    final storedListMode = _prefs.getString(_kMonitorListMode);
    var listMode = MonitorListMode.fromStorage(storedListMode);
    var listPackages =
        _prefs.getStringList(_kListPackages)?.toSet() ?? const <String>{};
    if (storedListMode == null && legacyBlacklist.isNotEmpty) {
      // 旧版本的“黑名单包名”自动迁移成黑名单模式，避免用户配置丢失。
      listMode = MonitorListMode.blacklist;
      listPackages = legacyBlacklist;
    }

    final schedule = ScheduleConfig(
      enabled: _prefs.getBool(_kScheduleEnabled) ?? false,
      startMinutes: _minutesOrDefault(_prefs.getInt(_kScheduleStart), 9 * 60),
      endMinutes: _minutesOrDefault(_prefs.getInt(_kScheduleEnd), 22 * 60),
      outsideMode: OutsideScheduleMode.fromStorage(
        _prefs.getString(_kScheduleOutsideMode),
      ),
    );

    return AppConfig(
      reminderMode: mode,
      thresholdMinutes: threshold,
      monitoringEnabled: _prefs.getBool(_kMonitoringEnabled) ?? true,
      autoStartEnabled: _prefs.getBool(_kAutoStartEnabled) ?? true,
      monitorListMode: listMode,
      listPackageNames: listPackages,
      debounceEnabled: _prefs.getBool(_kDebounceEnabled) ?? true,
      debugMode: _prefs.getBool(_kDebugMode) ?? false,
      focusSuppressUntilMs: _prefs.getInt(_kFocusSuppressUntil) ?? 0,
      schedule: schedule,
    );
  }

  /// 分钟数兜底：越界或缺失时回退到默认值。
  static int _minutesOrDefault(int? value, int fallback) {
    if (value == null || value < 0 || value >= 24 * 60) return fallback;
    return value;
  }

  /// 保存配置。失败时会抛出异常由上层统一提示。
  Future<void> save(AppConfig config) async {
    await _prefs.setString(_kReminderMode, config.reminderMode.storageKey);
    await _prefs.setInt(_kThresholdMinutes, config.thresholdMinutes);
    await _prefs.setBool(_kMonitoringEnabled, config.monitoringEnabled);
    await _prefs.setBool(_kAutoStartEnabled, config.autoStartEnabled);
    await _prefs.setString(_kMonitorListMode, config.monitorListMode.storageKey);
    await _prefs.setStringList(
      _kListPackages,
      config.listPackageNames.toList()..sort(),
    );
    await _prefs.remove(_kBlacklistedApps);
    await _prefs.setBool(_kDebounceEnabled, config.debounceEnabled);
    await _prefs.setBool(_kDebugMode, config.debugMode);
    await _prefs.setInt(_kFocusSuppressUntil, config.focusSuppressUntilMs);
    await _prefs.setBool(_kScheduleEnabled, config.schedule.enabled);
    await _prefs.setInt(_kScheduleStart, config.schedule.startMinutes);
    await _prefs.setInt(_kScheduleEnd, config.schedule.endMinutes);
    await _prefs.setString(
      _kScheduleOutsideMode,
      config.schedule.outsideMode.storageKey,
    );
  }
}
