import 'package:flutter/foundation.dart';
import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/features/monitoring/data/usage_stats_method_channel.dart';
import 'package:is_it_enough/features/settings/data/repositories/statistics_repository.dart';
import 'package:is_it_enough/features/statistics/domain/usage_report.dart';

/// 统计数据模型。
class AppStatistics {
  const AppStatistics({
    this.totalTriggers = 0,
    this.putDownCount = 0,
    this.continueCount = 0,
    this.lastTriggerTime,
  });

  final int totalTriggers;
  final int putDownCount;
  final int continueCount;
  final DateTime? lastTriggerTime;

  AppStatistics copyWith({
    int? totalTriggers,
    int? putDownCount,
    int? continueCount,
    DateTime? lastTriggerTime,
  }) {
    return AppStatistics(
      totalTriggers: totalTriggers ?? this.totalTriggers,
      putDownCount: putDownCount ?? this.putDownCount,
      continueCount: continueCount ?? this.continueCount,
      lastTriggerTime: lastTriggerTime ?? this.lastTriggerTime,
    );
  }
}

/// 统计服务。
///
/// 除累计触发/放下次数外，还负责按需拉取「今日使用量 + 时间线」：
/// 数据由原生 `UsageStatsBridge.getUsageTimeline` 从 UsageStatsManager 聚合，
/// 只读本地、不上传。
class StatisticsService extends ChangeNotifier {
  StatisticsService(
    this._repository, {
    UsageStatsMethodChannel? usageStats,
  }) : _usageStats = usageStats ?? UsageStatsMethodChannel();

  final StatisticsRepository _repository;
  final UsageStatsMethodChannel _usageStats;

  AppStatistics _stats = const AppStatistics();

  /// 今日各应用“触发超时次数”（包名 → 次数）。
  Map<String, int> _todayTriggerCounts = <String, int>{};

  UsageReport? _usageReport;
  bool _usageLoading = false;
  String? _usageError;
  bool _usageLoadedOnce = false;

  AppStatistics get stats => _stats;

  /// 今日各应用触发超时次数（只读快照）。
  Map<String, int> get todayTriggerCounts =>
      Map<String, int>.unmodifiable(_todayTriggerCounts);

  /// 某个应用今日触发超时的次数。
  int triggerCountFor(String packageName) =>
      _todayTriggerCounts[packageName] ?? 0;

  /// 今日使用量/时间线数据；尚未拉取或拉取失败时为 null。
  UsageReport? get usageReport => _usageReport;

  bool get usageLoading => _usageLoading;

  /// 拉取失败原因（无权限时提示用户去授权）。
  String? get usageError => _usageError;

  bool get usageLoadedOnce => _usageLoadedOnce;

  Future<void> load() async {
    _stats = await _repository.load();
    _todayTriggerCounts = _repository.loadTodayTriggerCounts();
    notifyListeners();
  }

  /// 记录一次触发提醒；[packageName] 用于今日各应用次数统计。
  Future<void> recordTrigger({String? packageName}) async {
    _stats = _stats.copyWith(
      totalTriggers: _stats.totalTriggers + 1,
      lastTriggerTime: DateTime.now(),
    );
    if (packageName != null && packageName.isNotEmpty) {
      _todayTriggerCounts = <String, int>{
        ..._todayTriggerCounts,
        packageName: (_todayTriggerCounts[packageName] ?? 0) + 1,
      };
      await _repository.saveTodayTriggerCounts(_todayTriggerCounts);
    }
    await _repository.save(_stats);
    notifyListeners();
  }

  Future<void> recordPutDown() async {
    _stats = _stats.copyWith(
      putDownCount: _stats.putDownCount + 1,
    );
    await _repository.save(_stats);
    notifyListeners();
  }

  Future<void> recordContinue() async {
    _stats = _stats.copyWith(
      continueCount: _stats.continueCount + 1,
    );
    await _repository.save(_stats);
    notifyListeners();
  }

  /// 重新拉取今日使用量/时间线。
  Future<void> refreshUsage({int days = 1}) async {
    if (_usageLoading) return;
    _usageLoading = true;
    notifyListeners();
    try {
      final raw = await _usageStats.getUsageTimeline(days: days);
      if (raw == null) {
        _usageError = 'NO_PERMISSION';
        _usageReport = null;
      } else {
        final report = UsageReport.fromJsonString(raw);
        _usageReport = report == null ? null : _filterIgnored(report);
        _usageError = null;
      }
    } catch (e) {
      _usageError = '$e';
      _usageReport = null;
    } finally {
      _usageLoadedOnce = true;
      _usageLoading = false;
      notifyListeners();
    }
  }

  /// 过滤系统桌面/设置等不参与判定的应用（与监控口径保持一致）。
  UsageReport _filterIgnored(UsageReport report) {
    final apps = report.apps
        .where((app) => !AppConstants.isIgnoredPackage(app.packageName))
        .toList();
    return UsageReport(
      dayStart: report.dayStart,
      generatedAt: report.generatedAt,
      apps: apps,
    );
  }

  Future<void> reset() async {
    _stats = const AppStatistics();
    _todayTriggerCounts = <String, int>{};
    await _repository.saveTodayTriggerCounts(_todayTriggerCounts);
    await _repository.save(_stats);
    notifyListeners();
  }
}
