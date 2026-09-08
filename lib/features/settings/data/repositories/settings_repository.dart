import 'package:is_it_enough/core/constants/app_constants.dart';
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
  static const _kBlacklistedApps = 'blacklisted_packages';
  static const _kDebounceEnabled = 'debounce_enabled';
  static const _kDebugMode = 'debug_mode';

  /// 读取本地配置；任何字段缺失时使用默认值。
  AppConfig load() {
    final mode = ReminderMode.fromStorage(_prefs.getString(_kReminderMode));
    final threshold = _prefs.getInt(_kThresholdMinutes) ??
        AppConstants.defaultThresholdMinutes;
    final blacklist = _prefs.getStringList(_kBlacklistedApps)?.toSet() ??
        const <String>{};

    return AppConfig(
      reminderMode: mode,
      thresholdMinutes: threshold,
      monitoringEnabled: _prefs.getBool(_kMonitoringEnabled) ?? true,
      blacklistedPackageNames: blacklist,
      debounceEnabled: _prefs.getBool(_kDebounceEnabled) ?? true,
      debugMode: _prefs.getBool(_kDebugMode) ?? false,
    );
  }

  /// 保存配置。失败时会抛出异常由上层统一提示。
  Future<void> save(AppConfig config) async {
    await _prefs.setString(_kReminderMode, config.reminderMode.storageKey);
    await _prefs.setInt(_kThresholdMinutes, config.thresholdMinutes);
    await _prefs.setBool(_kMonitoringEnabled, config.monitoringEnabled);
    await _prefs.setStringList(
      _kBlacklistedApps,
      config.blacklistedPackageNames.toList()..sort(),
    );
    await _prefs.setBool(_kDebounceEnabled, config.debounceEnabled);
    await _prefs.setBool(_kDebugMode, config.debugMode);
  }
}
