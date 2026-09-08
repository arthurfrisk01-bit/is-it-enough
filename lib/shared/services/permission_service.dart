import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:is_it_enough/features/monitoring/data/usage_stats_method_channel.dart';

/// 系统/厂商权限跳转服务。
///
/// - 使用情况访问：通过原生 `UsageStatsBridge` 的 MethodChannel 判断与跳转；
/// - 悬浮窗：使用 `android_intent_plus` 打开系统悬浮窗授权页；
/// - 后台自启/省电白名单：厂商 ROM 差异较大，后续按厂商单独实现。
class PermissionService {
  PermissionService({UsageStatsMethodChannel? usageStats})
      : _usageStats = usageStats ?? UsageStatsMethodChannel();

  final UsageStatsMethodChannel _usageStats;

  static const String _packageName = 'com.isitenough.app';

  /// 是否已授予使用情况访问权限。
  Future<bool> hasUsageAccess() => _usageStats.isUsageAccessGranted();

  /// 是否已授予悬浮窗权限（Android 6.0+）。
  Future<bool> hasOverlayPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        return await FlutterOverlayWindow.isPermissionGranted();
      } catch (e) {
        debugPrint('[Permission] hasOverlayPermission error: $e');
        return false;
      }
    }
    return true;
  }

  /// 跳转系统“使用情况访问”授权页。
  Future<void> requestUsageAccess() async {
    final opened = await _usageStats.openUsageAccessSettings();
    if (!opened) {
      throw StateError('无法打开使用情况访问设置页');
    }
  }

  /// 跳转 Android 悬浮窗权限设置页。
  Future<void> requestOverlayPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await FlutterOverlayWindow.requestPermission();
        if (result != true) {
          // 插件弹出系统授权页，用户手动授权
          debugPrint('[Permission] 用户需在设置中手动授予悬浮窗权限');
        }
      } catch (e) {
        debugPrint('[Permission] requestOverlayPermission error: $e');
      }
      return;
    }
    throw UnsupportedError('当前平台不支持悬浮窗权限跳转');
  }

  /// 打开后台自启/省电白名单设置。
  ///
  /// 不同厂商的 Intent 各不相同，MVP 先覆盖常见入口；
  /// 华为/小米/OPPO/vivo 的细化分支会在“防封杀适配”步骤补全。
  Future<void> openAutoStartSettings() async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('当前平台不支持后台自启设置');
    }

    // 尝试按厂商打开，失败的兜底放在 catch 中给出可读提示。
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final manufacturer = deviceInfo.manufacturer.toLowerCase();

    if (manufacturer.contains('xiaomi')) {
      const intent = AndroidIntent(
        action: 'miui.intent.action.OP_AUTO_START',
        data: 'package:$_packageName',
      );
      await intent.launch();
      return;
    }

    if (manufacturer.contains('huawei') ||
        manufacturer.contains('honor')) {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:$_packageName',
      );
      await intent.launch();
      return;
    }

    if (manufacturer.contains('oppo') ||
        manufacturer.contains('vivo') ||
        manufacturer.contains('oneplus')) {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:$_packageName',
      );
      await intent.launch();
      return;
    }

    // 通用兜底：打开应用详情页，由用户自行找到“电池/后台”选项。
    const intent = AndroidIntent(
      action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
      data: 'package:$_packageName',
    );
    await intent.launch();
  }
}
