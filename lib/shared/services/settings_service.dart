import 'package:flutter/foundation.dart';
import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/features/settings/data/models/app_config.dart';
import 'package:is_it_enough/features/settings/data/repositories/settings_repository.dart';

/// 设置中心：负责加载、修改、持久化 [AppConfig]。
///
/// 作为全局 `ChangeNotifier` 提供给 UI 与后台监听共同消费。
class SettingsService extends ChangeNotifier {
  SettingsService(this._repository);

  final SettingsRepository _repository;

  AppConfig _config = const AppConfig();

  AppConfig get config => _config;

  ReminderMode get reminderMode => _config.reminderMode;
  int get thresholdMinutes => _config.thresholdMinutes;
  bool get monitoringEnabled => _config.monitoringEnabled;
  Set<String> get blacklistedPackageNames => _config.blacklistedPackageNames;
  bool get debounceEnabled => _config.debounceEnabled;
  bool get debugMode => _config.debugMode;

  /// 应用启动时先同步读取一次本地配置。
  Future<void> load() async {
    _config = _repository.load();
    notifyListeners();
  }

  /// 设置提醒强度并持久化。
  Future<void> setReminderMode(ReminderMode mode) async {
    await _update(_config.copyWith(reminderMode: mode));
  }

  /// 设置触发阈值并持久化。
  Future<void> setThresholdMinutes(int minutes) async {
    if (!AppConstants.thresholdOptions.contains(minutes)) {
      throw ArgumentError.value(
        minutes,
        'minutes',
        '阈值必须是 ${AppConstants.thresholdOptions} 之一',
      );
    }
    await _update(_config.copyWith(thresholdMinutes: minutes));
  }

  /// 开启/关闭 Android 后台监控。
  Future<void> setMonitoringEnabled(bool enabled) async {
    await _update(_config.copyWith(monitoringEnabled: enabled));
  }

  /// 替换监控名单（去重并排序，保证持久化稳定）。
  Future<void> updateBlacklist(Set<String> packages) async {
    await _update(
      _config.copyWith(blacklistedPackageNames: {...packages}),
    );
  }

  /// 开启/关闭消抖功能。
  Future<void> setDebounceEnabled(bool enabled) async {
    await _update(_config.copyWith(debounceEnabled: enabled));
  }

  /// 开启/关闭调试模式。
  Future<void> setDebugMode(bool enabled) async {
    await _update(_config.copyWith(debugMode: enabled));
  }

  Future<void> _update(AppConfig next) async {
    _config = next;
    notifyListeners();
    await _repository.save(next);
  }
}
