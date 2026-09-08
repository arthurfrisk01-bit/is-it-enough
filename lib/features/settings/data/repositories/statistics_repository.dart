import 'package:is_it_enough/shared/services/statistics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 统计数据持久化。
class StatisticsRepository {
  StatisticsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyTotalTriggers = 'stats_total_triggers';
  static const _keyPutDown = 'stats_put_down';
  static const _keyContinue = 'stats_continue';
  static const _keyLastTrigger = 'stats_last_trigger';

  Future<AppStatistics> load() async {
    final totalTriggers = _prefs.getInt(_keyTotalTriggers) ?? 0;
    final putDown = _prefs.getInt(_keyPutDown) ?? 0;
    final continueCount = _prefs.getInt(_keyContinue) ?? 0;
    final lastTriggerMs = _prefs.getInt(_keyLastTrigger);

    return AppStatistics(
      totalTriggers: totalTriggers,
      putDownCount: putDown,
      continueCount: continueCount,
      lastTriggerTime:
          lastTriggerMs != null ? DateTime.fromMillisecondsSinceEpoch(lastTriggerMs) : null,
    );
  }

  Future<void> save(AppStatistics stats) async {
    await _prefs.setInt(_keyTotalTriggers, stats.totalTriggers);
    await _prefs.setInt(_keyPutDown, stats.putDownCount);
    await _prefs.setInt(_keyContinue, stats.continueCount);
    if (stats.lastTriggerTime != null) {
      await _prefs.setInt(_keyLastTrigger, stats.lastTriggerTime!.millisecondsSinceEpoch);
    }
  }
}
