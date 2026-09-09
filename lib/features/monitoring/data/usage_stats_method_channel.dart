import 'dart:async';

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

  /// 根据包名获取应用显示名称（ApplicationInfo.label）；未安装时返回 null。
  Future<String?> getAppLabel(String packageName) async {
    try {
      return await _channel.invokeMethod<String?>(
        'getAppLabel',
        {'packageName': packageName},
      );
    } on PlatformException catch (e) {
      debugPrint('[UsageStats] getAppLabel error: ${e.message}');
      return null;
    }
  }

  /// 今日（可指定天数）各应用使用会话，返回原生侧拼好的 JSON 字符串。
  ///
  /// 无“使用情况访问”权限时返回 null。带 5 秒超时：宿主未实现该通道时
  /// `invokeMethod` 的 Future 可能永远不完成（例如桌面预览/测试环境），
  /// 不能让统计页一直转圈。
  Future<String?> getUsageTimeline({int days = 1}) async {
    try {
      return await _channel
          .invokeMethod<String?>('getUsageTimeline', {'days': days})
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      debugPrint('[UsageStats] getUsageTimeline 超时（宿主未实现该通道？）');
      return null;
    } on PlatformException catch (e) {
      debugPrint('[UsageStats] getUsageTimeline error: ${e.message}');
      return null;
    }
  }
}
