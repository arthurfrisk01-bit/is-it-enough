/// 监控名单模式与时段限制相关的常量模型。
///
/// 这里只放纯数据与解析逻辑，UI 与数据层共用；所有配置都只存在本机
/// （SharedPreferences），不上传任何数据。
library;

/// 监控名单模式。
///
/// - [off]：不启用名单（默认），监控所有应用；
/// - [blacklist]：名单内的应用不监控；
/// - [whitelist]：只监控名单内的应用。
///
/// 黑名单与白名单互斥，同一时刻只有一种模式生效，也可以都不开启。
enum MonitorListMode {
  off('off', '不启用', '监控所有应用（默认）'),
  blacklist('blacklist', '黑名单', '名单里的应用不监控'),
  whitelist('whitelist', '白名单', '只监控名单里的应用');

  const MonitorListMode(this.storageKey, this.label, this.description);

  final String storageKey;
  final String label;
  final String description;

  static MonitorListMode fromStorage(String? value) {
    for (final mode in MonitorListMode.values) {
      if (mode.storageKey == value) return mode;
    }
    return MonitorListMode.off;
  }

  bool get isEnabled => this != MonitorListMode.off;
}

/// 时段外的提醒强度。
enum OutsideScheduleMode {
  off('off', '不提醒', '时段外只记录使用时长，不打扰'),
  soft('soft', '弱提醒', '时段外只显示轻量悬浮卡片'),
  strong('strong', '强提醒', '时段外仍然全屏阻断');

  const OutsideScheduleMode(this.storageKey, this.label, this.description);

  final String storageKey;
  final String label;
  final String description;

  static OutsideScheduleMode fromStorage(String? value) {
    for (final mode in OutsideScheduleMode.values) {
      if (mode.storageKey == value) return mode;
    }
    return OutsideScheduleMode.off;
  }
}

/// 时段限制配置（可选开启）。
///
/// 时段内按全局提醒强度提醒；时段外按 [outsideMode] 处理。
/// 支持跨零点时段（例如 22:00 – 07:00）。
class ScheduleConfig {
  const ScheduleConfig({
    this.enabled = false,
    this.startMinutes = 9 * 60,
    this.endMinutes = 22 * 60,
    this.outsideMode = OutsideScheduleMode.off,
  });

  /// 是否启用时段限制（默认关闭）。
  final bool enabled;

  /// 时段开始时间：当天 0 点起的分钟数。
  final int startMinutes;

  /// 时段结束时间：当天 0 点起的分钟数。
  final int endMinutes;

  /// 时段外的提醒强度。
  final OutsideScheduleMode outsideMode;

  /// 给定分钟数是否落在限制时段内。
  bool containsMinutes(int minutesOfDay) {
    if (startMinutes == endMinutes) return true; // 视为全天
    if (startMinutes < endMinutes) {
      return minutesOfDay >= startMinutes && minutesOfDay < endMinutes;
    }
    // 跨零点：22:00 – 07:00
    return minutesOfDay >= startMinutes || minutesOfDay < endMinutes;
  }

  /// 当前是否在限制时段内。
  bool containsNow([DateTime? now]) {
    final t = now ?? DateTime.now();
    return containsMinutes(t.hour * 60 + t.minute);
  }

  /// 把分钟数格式化为 HH:mm。
  static String formatMinutes(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String get label =>
      '${formatMinutes(startMinutes)} – ${formatMinutes(endMinutes)}';

  ScheduleConfig copyWith({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
    OutsideScheduleMode? outsideMode,
  }) {
    return ScheduleConfig(
      enabled: enabled ?? this.enabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
      outsideMode: outsideMode ?? this.outsideMode,
    );
  }
}
