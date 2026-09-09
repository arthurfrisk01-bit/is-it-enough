import 'dart:convert';

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
  static const _keyTriggerByApp = 'stats_trigger_by_app';
  static const _keyTriggerByAppDate = 'stats_trigger_by_app_date';

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

  /// 读取“今日各应用触发超时次数”。
  ///
  /// 只保留当天的数据：日期对不上（跨天/时区变化）时直接返回空表，
  /// 不需要额外的定时清理任务。
  Map<String, int> loadTodayTriggerCounts() {
    if (_prefs.getString(_keyTriggerByAppDate) != _todayKey()) {
      return <String, int>{};
    }
    final raw = _prefs.getString(_keyTriggerByApp);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      return <String, int>{
        for (final entry in decoded.entries)
          if (entry.value is int) entry.key.toString(): entry.value as int,
      };
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> saveTodayTriggerCounts(Map<String, int> counts) async {
    await _prefs.setString(_keyTriggerByAppDate, _todayKey());
    await _prefs.setString(_keyTriggerByApp, jsonEncode(counts));
  }

  /// 上次写入按应用计数的日期键；与 [todayKey] 不一致说明已跨天。
  String? storedTriggerCountsDateKey() =>
      _prefs.getString(_keyTriggerByAppDate);

  /// 今天的日期键，供上层判断跨天。
  static String todayKey() => _todayKey();

  static String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> save(AppStatistics stats) async {
    await _prefs.setInt(_keyTotalTriggers, stats.totalTriggers);
    await _prefs.setInt(_keyPutDown, stats.putDownCount);
    await _prefs.setInt(_keyContinue, stats.continueCount);
    final lastTriggerTime = stats.lastTriggerTime;
    if (lastTriggerTime != null) {
      await _prefs.setInt(
        _keyLastTrigger,
        lastTriggerTime.millisecondsSinceEpoch,
      );
    } else {
      // 重置统计后必须删掉旧值：否则内存已清空、prefs 仍留着上次触发时间，
      // 重启应用后“上次触发”会复活。
      await _prefs.remove(_keyLastTrigger);
    }
  }
}
