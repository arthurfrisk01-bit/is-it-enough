import 'reminder_modes.dart';

/// 全局常量。
class AppConstants {
  AppConstants._();

  /// 应用展示名称。
  static const String appName = '够了吗';

  /// Android 侧后台监听轮询间隔。
  static const Duration usagePollInterval = Duration(seconds: 5);

  /// 默认触发阈值。
  static const int defaultThresholdMinutes = 10;

  /// 可选的触发阈值（分钟）。
  static const List<int> thresholdOptions = [5, 10, 15, 20];

  /// “再刷 5 分钟”连续点击次数上限。
  static const int maxSnoozeCount = 3;

  /// 超过 [maxSnoozeCount] 次后，自动缩短为“再刷 2 分钟”。
  static const int shortenedSnoozeMinutes = 2;

  /// 弱/强提醒默认模式。
  static const ReminderMode defaultReminderMode = ReminderMode.strong;

  /// 消抖时间窗口：切换应用后在此时间内返回原应用，继续累计时间。
  static const Duration debounceDuration = Duration(seconds: 30);

  /// “正在专注，勿扰”默认时长：1 小时。
  ///
  /// 用户在提醒页/悬浮窗点“专注 1 小时”后，这段时间内不再触发任何提醒，
  /// 也不累计会话时长（避免勿扰结束后立刻又被判定为超时）。
  static const Duration focusSuppressDuration = Duration(hours: 1);

  /// 不参与“刷手机”判定的系统包/桌面前缀。
  ///
  /// 监控判定、统计时间线、使用量统计共用这一份名单，避免三处各写一份
  /// 导致口径不一致（例如时间线里冒出“系统桌面”）。
  static const List<String> ignoredPackagePrefixes = [
    'com.android.systemui', // Android 系统 UI
    'com.android.launcher', // 原生桌面
    'com.google.android.apps.nexuslauncher', // Pixel 桌面
    'com.miui.home', // 小米桌面
    'com.huawei.android.launcher', // 华为桌面
    'com.oppo.launcher', // OPPO 桌面
    'com.vivo.launcher', // vivo 桌面
    'com.samsung.android.app.launcher', // 三星桌面
    'com.meizu.flyme.launcher', // 魅族桌面
    'com.oneplus.launcher', // 一加桌面
    'com.realme.launcher', // Realme 桌面
    'com.transsion.hilauncher', // 传音桌面
    'com.teslacoilsw.launcher', // Nova Launcher
    'com.microsoft.launcher', // Microsoft Launcher
    'com.android.settings', // 系统设置
    'com.android.vending', // Google Play
    'com.android.permissioncontroller', // 权限控制器
  ];

  /// 判断包名是否属于“不参与判定”的系统包/桌面。
  static bool isIgnoredPackage(String packageName) {
    if (packageName == 'com.isitenough.app') return true;
    return ignoredPackagePrefixes.any(packageName.startsWith);
  }
}
