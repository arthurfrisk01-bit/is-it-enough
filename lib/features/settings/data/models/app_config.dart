import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';

/// 应用配置快照。
///
/// 所有字段均为纯本地配置，不上传任何数据。
class AppConfig {
  const AppConfig({
    this.reminderMode = AppConstants.defaultReminderMode,
    this.thresholdMinutes = AppConstants.defaultThresholdMinutes,
    this.monitoringEnabled = true,
    this.autoStartEnabled = true,
    this.blacklistedPackageNames = const <String>{},
    this.debounceEnabled = true,
    this.debugMode = false,
    this.focusSuppressUntilMs = 0,
  });

  /// 提醒强度：弱 / 强。
  final ReminderMode reminderMode;

  /// 连续使用同一 App 达到该分钟数后触发提醒。
  final int thresholdMinutes;

  /// Android 后台监听总开关。
  final bool monitoringEnabled;

  /// 开机自启动开关：重启/应用更新后是否自动恢复后台监控服务。
  ///
  /// 关掉后 [BootReceiver] 不再拉起保活服务，用户需手动打开 App。
  final bool autoStartEnabled;

  /// 监控名单：若非空，则只监控这些包名；为空时表示监控所有非白名单应用。
  ///
  /// MVP 先提供“黑名单/名单编辑”的存储结构，后续可扩展为白名单语义。
  final Set<String> blacklistedPackageNames;

  /// 消抖开关：短暂切换其他应用30s内回到原应用继续计算提醒时间。
  final bool debounceEnabled;

  /// 调试模式：开启后提醒时间变为1分钟，日志全量输出。
  final bool debugMode;

  /// “专注勿扰”截止时刻（epoch 毫秒）；0 表示当前没有勿扰。
  ///
  /// 放在配置里而不是仅存在内存中：进程被杀/重启后勿扰仍然有效，
  /// 无界面引擎与界面引擎读的是同一份值。
  final int focusSuppressUntilMs;

  /// 勿扰截止时刻；已过期或未设置时返回 null。
  DateTime? get focusSuppressUntil {
    if (focusSuppressUntilMs <= 0) return null;
    final until = DateTime.fromMillisecondsSinceEpoch(focusSuppressUntilMs);
    return until.isAfter(DateTime.now()) ? until : null;
  }

  AppConfig copyWith({
    ReminderMode? reminderMode,
    int? thresholdMinutes,
    bool? monitoringEnabled,
    bool? autoStartEnabled,
    Set<String>? blacklistedPackageNames,
    bool? debounceEnabled,
    bool? debugMode,
    int? focusSuppressUntilMs,
  }) {
    return AppConfig(
      reminderMode: reminderMode ?? this.reminderMode,
      thresholdMinutes: thresholdMinutes ?? this.thresholdMinutes,
      monitoringEnabled: monitoringEnabled ?? this.monitoringEnabled,
      autoStartEnabled: autoStartEnabled ?? this.autoStartEnabled,
      blacklistedPackageNames:
          blacklistedPackageNames ?? this.blacklistedPackageNames,
      debounceEnabled: debounceEnabled ?? this.debounceEnabled,
      debugMode: debugMode ?? this.debugMode,
      focusSuppressUntilMs: focusSuppressUntilMs ?? this.focusSuppressUntilMs,
    );
  }
}
