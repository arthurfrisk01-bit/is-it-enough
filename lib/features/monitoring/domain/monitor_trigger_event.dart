/// 达到阈值后由监听器发出的“该提醒了”事件。
///
/// Overlay/提醒模块只需要消费该事件，不需要知道底层 UsageStats 细节。
class MonitorTriggerEvent {
  const MonitorTriggerEvent({
    required this.packageName,
    required this.continuousSeconds,
    this.appLabel,
  });

  /// 当前被判定为“刷了太久”的应用包名。
  final String packageName;

  /// 应用显示名称（如"微信"），未获取到时为 null。
  final String? appLabel;

  /// 该应用本次连续前台秒数（仅用于统计/日志）。
  final int continuousSeconds;

  @override
  String toString() =>
      'MonitorTriggerEvent(packageName: $packageName, '
      'appLabel: $appLabel, '
      'continuousSeconds: $continuousSeconds)';
}
