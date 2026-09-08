import 'dart:async';

import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/features/monitoring/data/usage_stats_method_channel.dart';
import 'package:is_it_enough/features/monitoring/domain/monitor_trigger_event.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';

/// Android 前台应用轮询监听器。
///
/// - 每 [AppConstants.usagePollInterval] 查询一次前台包名；
/// - 连续使用同一应用达到阈值后发出 [MonitorTriggerEvent]；
/// - 支持“再刷 5/2 分钟”的强制延后提醒（通过 [snooze] 设置强制触发点）。
///
/// 该类只在 Android 上启用；iOS 版不启动轮询。
class ForegroundMonitor {
  ForegroundMonitor({
    required UsageStatsMethodChannel usageStats,
    required SettingsService settingsService,
    required void Function(MonitorTriggerEvent event) onTrigger,
  })  : _usageStats = usageStats,
        _settings = settingsService,
        _onTrigger = onTrigger;

  final UsageStatsMethodChannel _usageStats;
  final SettingsService _settings;
  final void Function(MonitorTriggerEvent event) _onTrigger;

  Timer? _timer;
  bool _running = false;

  /// 当前处于前台的包名。
  String? _currentPackage;

  /// 当前包名的连续开始时间。
  DateTime? _currentSince;

  /// 当前连续会话是否已经触发过提醒（避免未处理时每 5 秒重复触发）。
  bool _sessionTriggered = false;

  /// 用户选择“再刷 X 分钟”后的强制提醒时刻。
  DateTime? _forcedTriggerAt;

  /// 用户选择“再刷 X 分钟”后的屏蔽截止时刻。
  DateTime? _suppressedUntil;

  bool get isRunning => _running;

  /// 启动轮询。已运行时忽略。
  void start() {
    if (_running) return;
    _running = true;
    unawaited(_tick());
    _timer = Timer.periodic(
      AppConstants.usagePollInterval,
      (_) => unawaited(_tick()),
    );
  }

  /// 停止轮询并清空会话状态。
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _resetSession();
  }

  /// 重置当前会话（例如用户进入呼吸页/主动放下后调用）。
  void resetSession() {
    _resetSession();
  }

  /// 用户点击“再刷 5 分钟/2 分钟”后调用。
  ///
  /// 在 [duration] 内不再因阈值提醒，但到点后若仍停留在同一应用，
  /// 会“强行”再次触发提醒。
  void snooze(Duration duration) {
    final now = DateTime.now();
    _suppressedUntil = now.add(duration);
    _forcedTriggerAt = now.add(duration);
    // 标记已触发，防止屏蔽期内走普通阈值判断。
    _sessionTriggered = true;
  }

  Future<void> _tick() async {
    if (!_running) return;
    if (!_settings.monitoringEnabled) {
      _resetSession();
      return;
    }

    final granted = await _usageStats.isUsageAccessGranted();
    if (!granted) {
      _resetSession();
      return;
    }

    final package = await _usageStats.getForegroundPackage();
    if (package == null || package.isEmpty) {
      _resetSession();
      return;
    }

    // 系统/桌面/自身等不应参与“刷手机”判定。
    if (_shouldIgnore(package)) {
      _resetSession();
      return;
    }

    final now = DateTime.now();

    // 切换到另一个 App：开启新的连续会话。
    if (package != _currentPackage) {
      _currentPackage = package;
      _currentSince = now;
      _sessionTriggered = false;
      _forcedTriggerAt = null;
      _suppressedUntil = null;
      return;
    }

    // 仍在“再刷 X 分钟”屏蔽期内。
    final suppressedUntil = _suppressedUntil;
    if (suppressedUntil != null && now.isBefore(suppressedUntil)) {
      return;
    }

    final elapsed = now.difference(_currentSince ?? now);

    // 1) 到“再刷”强制时刻：无论是否达到阈值都再次提醒。
    final forcedAt = _forcedTriggerAt;
    if (forcedAt != null && !now.isBefore(forcedAt)) {
      _sessionTriggered = true;
      _onTrigger(
        MonitorTriggerEvent(
          packageName: package,
          continuousSeconds: elapsed.inSeconds,
        ),
      );
      return;
    }

    // 2) 普通阈值触发：连续使用达到设置时长。
    if (!_sessionTriggered &&
        elapsed >= Duration(minutes: _settings.thresholdMinutes)) {
      _sessionTriggered = true;
      _onTrigger(
        MonitorTriggerEvent(
          packageName: package,
          continuousSeconds: elapsed.inSeconds,
        ),
      );
    }
  }

  bool _shouldIgnore(String packageName) {
    // 自身不应被监控。
    if (packageName == 'com.isitenough.app') return true;

    // MVP 黑名单：名单内的包不触发。
    if (_settings.blacklistedPackageNames.contains(packageName)) return true;

    // 常见系统包/桌面，避免误判。
    const ignoredPrefixes = [
      'android',
      'com.android.systemui',
      'com.google.android.apps.nexuslauncher',
      'com.miui.home',
      'com.huawei.android.launcher',
      'com.oppo.launcher',
      'com.vivo.launcher',
    ];
    return ignoredPrefixes.any(packageName.startsWith);
  }

  void _resetSession() {
    _currentPackage = null;
    _currentSince = null;
    _sessionTriggered = false;
    _forcedTriggerAt = null;
    _suppressedUntil = null;
  }
}
