import 'package:flutter/foundation.dart';
import 'package:is_it_enough/features/settings/data/repositories/statistics_repository.dart';

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
class StatisticsService extends ChangeNotifier {
  StatisticsService(this._repository);

  final StatisticsRepository _repository;
  AppStatistics _stats = const AppStatistics();

  AppStatistics get stats => _stats;

  Future<void> load() async {
    _stats = await _repository.load();
    notifyListeners();
  }

  Future<void> recordTrigger() async {
    _stats = _stats.copyWith(
      totalTriggers: _stats.totalTriggers + 1,
      lastTriggerTime: DateTime.now(),
    );
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

  Future<void> reset() async {
    _stats = const AppStatistics();
    await _repository.save(_stats);
    notifyListeners();
  }
}
