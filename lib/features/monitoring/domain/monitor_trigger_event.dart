/// 达到阈值后由监听器发出的“该提醒了”事件。
///
/// Overlay/提醒模块只需要消费该事件，不需要知道底层 UsageStats 细节。
class MonitorTriggerEvent {
  const MonitorTriggerEvent({
    required this.packageName,
    required this.continuousSeconds,
  });

  /// 当前被判定为“刷了太久”的应用包名。
  final String packageName;

  /// 该应用本次连续前台秒数（仅用于统计/日志）。
  final int continuousSeconds;

  @override
  String toString() =>
      'MonitorTriggerEvent(packageName: $packageName, '
      'continuousSeconds: $continuousSeconds)';
}
