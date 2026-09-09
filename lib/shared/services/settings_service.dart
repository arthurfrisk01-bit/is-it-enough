import 'package:flutter/foundation.dart';
import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/core/constants/monitor_list_modes.dart';
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
  bool get autoStartEnabled => _config.autoStartEnabled;
  MonitorListMode get monitorListMode => _config.monitorListMode;
  Set<String> get listPackageNames => _config.listPackageNames;
  ScheduleConfig get schedule => _config.schedule;
  bool get debounceEnabled => _config.debounceEnabled;
  bool get debugMode => _config.debugMode;

  /// 当前生效的提醒强度。
  ///
  /// 时段限制未开启时就是 [reminderMode]；开启后，时段内同样用
  /// [reminderMode]，时段外取 [ScheduleConfig.outsideMode]
  /// （返回 null 表示时段外完全不提醒）。
  ReminderMode? get effectiveReminderModeNow {
    final s = _config.schedule;
    if (!s.enabled || s.containsNow()) return _config.reminderMode;
    switch (s.outsideMode) {
      case OutsideScheduleMode.off:
        return null;
      case OutsideScheduleMode.soft:
        return ReminderMode.soft;
      case OutsideScheduleMode.strong:
        return ReminderMode.strong;
    }
  }

  /// “专注勿扰”截止时刻；未开启或已过期时为 null。
  DateTime? get focusSuppressUntil => _config.focusSuppressUntil;

  /// 当前是否处于“专注勿扰”期内。
  bool get isFocusSuppressed => _config.focusSuppressUntil != null;

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

  /// 开启/关闭开机自启动。
  Future<void> setAutoStartEnabled(bool enabled) async {
    await _update(_config.copyWith(autoStartEnabled: enabled));
  }

  /// 切换监控名单模式（不启用 / 黑名单 / 白名单）。
  Future<void> setMonitorListMode(MonitorListMode mode) async {
    await _update(_config.copyWith(monitorListMode: mode));
  }

  /// 替换名单里的包名集合（去重，保证持久化稳定）。
  Future<void> updateListPackages(Set<String> packages) async {
    await _update(_config.copyWith(listPackageNames: {...packages}));
  }

  /// 更新时段限制配置。
  Future<void> updateSchedule(ScheduleConfig schedule) async {
    await _update(_config.copyWith(schedule: schedule));
  }

  /// 开启/关闭消抖功能。
  Future<void> setDebounceEnabled(bool enabled) async {
    await _update(_config.copyWith(debounceEnabled: enabled));
  }

  /// 开启/关闭调试模式。
  Future<void> setDebugMode(bool enabled) async {
    await _update(_config.copyWith(debugMode: enabled));
  }

  /// 开启“专注勿扰”：[duration] 内不再触发提醒。
  Future<void> suppressFocus({Duration duration = AppConstants.focusSuppressDuration}) async {
    final until = DateTime.now().add(duration).millisecondsSinceEpoch;
    await _update(_config.copyWith(focusSuppressUntilMs: until));
  }

  /// 提前结束“专注勿扰”。
  Future<void> clearFocusSuppression() async {
    await _update(_config.copyWith(focusSuppressUntilMs: 0));
  }

  Future<void> _update(AppConfig next) async {
    _config = next;
    notifyListeners();
    await _repository.save(next);
  }
}
