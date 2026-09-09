import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';

/// 原生全屏提醒悬浮窗的 Dart 侧通道。
///
/// 原生实现见 `android/app/src/main/kotlin/com/isitenough/app/ReminderOverlay.kt`。
///
/// 与旧的 `flutter_overlay_window` 方案相比：不再有独立 Flutter 引擎，也没有
/// `shareData` 握手 —— 实机上那套链路从不回执，导致“只弹通知、没有全屏”。
/// 这里 `show()` 同步返回窗口是否真的挂到了 WindowManager 上。
class ReminderOverlayChannel {
  ReminderOverlayChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.isitenough.app/reminder_overlay');

  static final _logger = LoggerService();

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// 注册悬浮窗按钮（`snooze` / `putDown`）回传的处理器。
  static void setActionHandler(void Function(String action) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'action') {
        final action = call.arguments as String?;
        if (action != null) handler(action);
      }
      return null;
    });
  }

  /// 是否已授予“显示在其他应用上层”权限。
  static Future<bool> isPermissionGranted() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isPermissionGranted') ?? false;
    } on PlatformException catch (e) {
      _logger.warning('读取悬浮窗权限失败: ${e.message}', tag: 'Overlay');
      return false;
    }
  }

  /// 跳转系统悬浮窗授权页。
  static Future<void> requestPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } on PlatformException catch (e) {
      _logger.warning('打开悬浮窗授权页失败: ${e.message}', tag: 'Overlay');
    }
  }

  /// 当前是否有悬浮窗显示在屏幕上（诊断用）。
  static Future<bool> isShowing() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isShowing') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 显示提醒悬浮窗，返回窗口是否真的挂上了（同步确认，无需握手）。
  static Future<bool> show({
    required String mode,
    required String appName,
    required int snoozeMinutes,
    required int continuousMinutes,
  }) async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('show', <String, dynamic>{
            'mode': mode,
            'appName': appName,
            'snoozeMinutes': snoozeMinutes,
            'continuousMinutes': continuousMinutes,
          }) ??
          false;
    } on PlatformException catch (e) {
      _logger.error('显示原生悬浮窗失败: ${e.message}', tag: 'Overlay');
      return false;
    }
  }

  /// 关闭悬浮窗。
  static Future<void> hide() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('hide');
    } on PlatformException catch (e) {
      _logger.debug('关闭悬浮窗失败: ${e.message}', tag: 'Overlay');
    } on MissingPluginException {
      // 宿主未实现（如桌面预览）时忽略。
    }
  }
}
