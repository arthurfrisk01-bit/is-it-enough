import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// 对 `flutter_overlay_window` 的轻封装。
///
/// 主要隔离插件 API，方便后续：
/// - 增加弱/强提醒的不同 Overlay 尺寸；
/// - 在无法使用全局悬浮窗的平台上回退到 App 内全屏页面。
class OverlayWindowService {
  const OverlayWindowService._();

  /// 是否已授予悬浮窗权限。
  static Future<bool> isPermissionGranted() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      debugPrint('[Overlay] isPermissionGranted error: $e');
      return false;
    }
  }

  /// 请求悬浮窗权限。
  static Future<bool> requestPermission() async {
    try {
      return (await FlutterOverlayWindow.requestPermission()) ?? false;
    } catch (e) {
      debugPrint('[Overlay] requestPermission error: $e');
      return false;
    }
  }

  /// 展示全局 Overlay。
  ///
  /// 注意：不同 Overlay 模式建议使用不同尺寸，这里保留扩展点；
  /// 具体 resize 取决于 `flutter_overlay_window` 当前版本 API。
  static Future<void> show() async {
    try {
      await FlutterOverlayWindow.showOverlay();
    } catch (e) {
      debugPrint('[Overlay] show error: $e');
      rethrow;
    }
  }

  /// 关闭全局 Overlay。
  static Future<void> hide() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('[Overlay] close error: $e');
    }
  }

  /// 向 Overlay 内的 Dart 入口发送当前提醒数据。
  static Future<void> sendReminderData({
    required String mode,
    required String packageName,
    required int snoozeMinutes,
  }) async {
    await sendData({
      'mode': mode,
      'packageName': packageName,
      'snoozeMinutes': snoozeMinutes,
    });
  }

  /// 通用发送数据到 Overlay / 从 Overlay 返回主 App。
  static Future<void> sendData(Map<String, dynamic> data) async {
    try {
      await FlutterOverlayWindow.shareData(data);
    } catch (e) {
      debugPrint('[Overlay] shareData error: $e');
    }
  }
}
