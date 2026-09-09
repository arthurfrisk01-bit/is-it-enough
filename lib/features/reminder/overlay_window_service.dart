import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';

/// 对 `flutter_overlay_window` 的轻封装。
///
/// 主要隔离插件 API，方便后续：
/// - 增加弱/强提醒的不同 Overlay 尺寸；
/// - 在无法使用全局悬浮窗的平台上回退到 App 内全屏页面。
///
/// 所有失败路径都会写入 [LoggerService]，确保应用日志页可见（不再静默吞错）。
class OverlayWindowService {
  const OverlayWindowService._();

  static final _logger = LoggerService();

  /// 是否已授予悬浮窗权限。
  static Future<bool> isPermissionGranted() async {
    try {
      return await FlutterOverlayWindow.isPermissionGranted();
    } catch (e) {
      _logger.error('悬浮窗权限检测失败: $e', tag: 'Overlay');
      return false;
    }
  }

  /// 请求悬浮窗权限。
  static Future<bool> requestPermission() async {
    try {
      return (await FlutterOverlayWindow.requestPermission()) ?? false;
    } catch (e) {
      _logger.error('请求悬浮窗权限失败: $e', tag: 'Overlay');
      return false;
    }
  }

  /// Overlay 服务当前是否真的在运行（后台拉起前台服务可能被系统静默丢弃，
  /// show() 成功不代表窗口真的出现，必须用这个状态二次确认）。
  static Future<bool> isActive() async {
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (e) {
      _logger.debug('查询 Overlay 状态失败: $e', tag: 'Overlay');
      return false;
    }
  }

  /// 展示全局 Overlay。
  ///
  /// Overlay 会伴随一条前台服务通知，默认文案为插件自带的英文
  /// “overlay activated”，这里改成中文。
  static Future<void> show({
    String? overlayTitle,
    String? overlayContent,
  }) async {
    try {
      await FlutterOverlayWindow.showOverlay(
        overlayTitle: overlayTitle ?? '够了吗：提醒服务运行中',
        overlayContent: overlayContent ?? '点击返回够了吗',
      );
    } catch (e) {
      _logger.error('Overlay show 失败: $e', tag: 'Overlay');
      rethrow;
    }
  }

  /// 关闭全局 Overlay。
  static Future<void> hide() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      _logger.debug('Overlay close 失败: $e', tag: 'Overlay');
    }
  }

  /// 向 Overlay 内的 Dart 入口发送当前提醒数据。
  ///
  /// [appName] 是给用户看应用名称（如“微信”）；缺失时 Overlay 侧回退到
  /// [packageName]，避免出现“你已经在 com.tencent.mm 上停留太久”这种提示。
  static Future<void> sendReminderData({
    required String mode,
    required String packageName,
    required int snoozeMinutes,
    String? appName,
  }) async {
    await sendData({
      'mode': mode,
      'packageName': packageName,
      'appName': appName,
      'snoozeMinutes': snoozeMinutes,
    });
  }

  /// 通用发送数据到 Overlay / 从 Overlay 返回主 App。
  static Future<void> sendData(Map<String, dynamic> data) async {
    try {
      await FlutterOverlayWindow.shareData(data);
    } catch (e) {
      _logger.error('Overlay shareData 失败: $e', tag: 'Overlay');
    }
  }
}
