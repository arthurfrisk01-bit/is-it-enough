import 'dart:convert';

/// 一次应用使用会话。
class UsageSession {
  const UsageSession({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  factory UsageSession.fromJson(Map<String, dynamic> json) {
    return UsageSession(
      start: DateTime.fromMillisecondsSinceEpoch(
        (json['start'] as num?)?.toInt() ?? 0,
      ),
      end: DateTime.fromMillisecondsSinceEpoch(
        (json['end'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// 单个应用当日的使用汇总。
class AppUsage {
  const AppUsage({
    required this.packageName,
    required this.label,
    required this.total,
    required this.sessions,
  });

  final String packageName;

  /// 应用显示名（拿不到时原生侧回退为包名最后一段）。
  final String label;

  /// 当日累计使用时长。
  final Duration total;

  /// 当日的使用会话（按结束时间倒序）。
  final List<UsageSession> sessions;

  factory AppUsage.fromJson(Map<String, dynamic> json) {
    final rawSessions = (json['sessions'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UsageSession.fromJson)
        .toList()
      ..sort((a, b) => b.end.compareTo(a.end));
    return AppUsage(
      packageName: json['package'] as String? ?? '',
      label: json['label'] as String? ?? '',
      total: Duration(milliseconds: (json['totalMs'] as num?)?.toInt() ?? 0),
      sessions: rawSessions,
    );
  }
}

/// 统计页“今日使用量 + 时间线”数据快照。
class UsageReport {
  const UsageReport({
    required this.dayStart,
    required this.generatedAt,
    required this.apps,
  });

  final DateTime dayStart;
  final DateTime generatedAt;

  /// 按累计使用时长倒序。
  final List<AppUsage> apps;

  bool get isEmpty => apps.isEmpty;

  /// 当日累计使用总时长（仅统计参与判定的应用）。
  Duration get totalUsage =>
      apps.fold(Duration.zero, (sum, app) => sum + app.total);

  /// 时间线：把所有会话按开始时间倒序摊平。
  ///
  /// 过滤掉不足 1 分钟的碎片会话（切来切去的误触记录），避免刷屏。
  List<TimelineEntry> get timeline {
    final entries = <TimelineEntry>[];
    for (final app in apps) {
      for (final session in app.sessions) {
        if (session.duration < const Duration(minutes: 1)) continue;
        entries.add(TimelineEntry(app: app, session: session));
      }
    }
    entries.sort((a, b) => b.session.start.compareTo(a.session.start));
    return entries;
  }

  static UsageReport? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;

    final apps = (decoded['apps'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AppUsage.fromJson)
        .where((app) => app.packageName.isNotEmpty && app.total > Duration.zero)
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return UsageReport(
      dayStart: DateTime.fromMillisecondsSinceEpoch(
        (decoded['start'] as num?)?.toInt() ?? 0,
      ),
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
        (decoded['end'] as num?)?.toInt() ?? 0,
      ),
      apps: apps,
    );
  }
}

/// 时间线里的一条记录（应用 + 会话）。
class TimelineEntry {
  const TimelineEntry({required this.app, required this.session});

  final AppUsage app;
  final UsageSession session;
}

/// 把时长格式化成「1 小时 5 分钟 / 12 分钟 / 45 秒」。
String formatUsageDuration(Duration duration) {
  if (duration.inMinutes < 1) {
    return '${duration.inSeconds} 秒';
  }
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours > 0) {
    return minutes > 0 ? '$hours 小时 $minutes 分钟' : '$hours 小时';
  }
  return '$minutes 分钟';
}

/// 把时刻格式化成「HH:mm」。
String formatClock(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
