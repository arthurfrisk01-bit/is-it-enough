import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart 侧对 Android `UsageStatsBridge` 的封装。
///
/// MethodChannel 名称必须与 Kotlin 侧保持一致。
class UsageStatsMethodChannel {
  UsageStatsMethodChannel({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(
          'com.isitenough.app/usage_stats',
        );

  final MethodChannel _channel;

  /// 是否已授予“使用情况访问权限”。
  Future<bool> isUsageAccessGranted() async {
    try {
      final granted = await _channel.invokeMethod<bool>('isUsageAccessGranted');
      return granted ?? false;
    } on PlatformException catch (e) {
      debugPrint('[UsageStats] isUsageAccessGranted error: ${e.message}');
      return false;
    }
  }

  /// 跳转系统“使用情况访问权限”设置页。
  Future<bool> openUsageAccessSettings() async {
    try {
      final opened =
          await _channel.invokeMethod<bool>('openUsageAccessSettings');
      return opened ?? false;
    } on PlatformException catch (e) {
      debugPrint('[UsageStats] openUsageAccessSettings error: ${e.message}');
      return false;
    }
  }

  /// 返回最近 2 分钟内最可能位于前台的应用包名；无权限或失败时为 null。
  Future<String?> getForegroundPackage() async {
    try {
      return await _channel.invokeMethod<String?>('getForegroundPackage');
    } on PlatformException catch (e) {
      debugPrint('[UsageStats] getForegroundPackage error: ${e.message}');
      return null;
    }
  }
}
