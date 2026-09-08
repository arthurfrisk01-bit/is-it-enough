/// 提醒强度模式。
///
/// - [soft]：弱提醒（轻量悬浮卡片，不阻断当前操作）。
/// - [strong]：强提醒（全屏毛玻璃遮罩 + 呼吸动画，默认）。
enum ReminderMode {
  soft('soft', '弱提醒', '轻量悬浮卡片，不阻断当前操作'),
  strong('strong', '强提醒', '全屏阻断遮罩 + 呼吸动画（默认）');

  const ReminderMode(this.storageKey, this.label, this.description);

  /// 持久化到 SharedPreferences 的字符串值。
  final String storageKey;

  /// 设置页展示名称。
  final String label;

  /// 设置页副标题。
  final String description;

  /// 从持久化字符串解析，解析失败时回退到 [strong]。
  static ReminderMode fromStorage(String? value) {
    return ReminderMode.values.firstWhere(
      (mode) => mode.storageKey == value,
      orElse: () => ReminderMode.strong,
    );
  }
}
