import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:is_it_enough/features/reminder/overlay_window_service.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限诊断服务：深度检查所有涉及通知/悬浮窗的权限状态。
///
/// 用于排查"所有权限都给了但通知依然无法显示"的问题。
class PermissionDiagnosisService {
  final logger = LoggerService();

  /// 执行完整权限诊断并返回诊断报告。
  Future<PermissionDiagnosisReport> diagnose() async {
    if (kIsWeb || !Platform.isAndroid) {
      return PermissionDiagnosisReport(platform: 'non-Android', items: []);
    }

    logger.info('=== 开始权限深度诊断 ===', tag: 'PermissionDiag');

    final items = <DiagnosisItem>[];

    // 1. POST_NOTIFICATIONS 权限（Android 13+）
    try {
      final notificationStatus = await Permission.notification.status;
      items.add(DiagnosisItem(
        name: 'POST_NOTIFICATIONS (Android 13+)',
        status: notificationStatus.isGranted
            ? DiagnosisStatus.ok
            : DiagnosisStatus.error,
        detail: '系统通知权限：${notificationStatus.name}',
        suggestion: notificationStatus.isGranted
            ? null
            : '请在系统设置 -> 应用 -> 够了吗 -> 通知 中开启通知权限',
      ));
    } catch (e) {
      items.add(DiagnosisItem(
        name: 'POST_NOTIFICATIONS 检查',
        status: DiagnosisStatus.error,
        detail: '检查失败: $e',
      ));
    }

    // 2. 检查 NotificationChannel 是否存在（通过插件）
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final androidImpl = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImpl != null) {
        // 尝试请求权限来判断是否可用
        final permissionGranted =
            await androidImpl.requestNotificationsPermission();
        items.add(DiagnosisItem(
          name: '通知插件运行时权限',
          status: permissionGranted == true
              ? DiagnosisStatus.ok
              : DiagnosisStatus.warning,
          detail: '插件 requestNotificationsPermission: $permissionGranted',
          suggestion: permissionGranted != true ? '通知权限可能被拒绝或未授予' : null,
        ));
      }
    } catch (e) {
      items.add(DiagnosisItem(
        name: '通知插件检查',
        status: DiagnosisStatus.warning,
        detail: '插件检查异常: $e',
      ));
    }

    // 3. SYSTEM_ALERT_WINDOW 悬浮窗权限
    try {
      final overlayGranted = await OverlayWindowService.isPermissionGranted();
      items.add(DiagnosisItem(
        name: 'SYSTEM_ALERT_WINDOW (悬浮窗)',
        status: overlayGranted ? DiagnosisStatus.ok : DiagnosisStatus.warning,
        detail: '悬浮窗权限：${overlayGranted ? "已授予" : "未授予"}',
        suggestion: overlayGranted
            ? null
            : '请在系统设置 -> 应用 -> 够了吗 -> 悬浮窗 中开启权限',
      ));
    } catch (e) {
      items.add(DiagnosisItem(
        name: 'SYSTEM_ALERT_WINDOW 检查',
        status: DiagnosisStatus.error,
        detail: '检查失败: $e',
      ));
    }

    // 4. 后台弹出界面权限（部分厂商 ROM 特有）
    try {
      final status = await Permission.systemAlertWindow.status;
      items.add(DiagnosisItem(
        name: '后台弹出界面权限（厂商特有）',
        status: status.isGranted ? DiagnosisStatus.ok : DiagnosisStatus.warning,
        detail: '后台弹出权限：${status.name}',
        suggestion: status.isGranted
            ? null
            : '部分厂商需要在"权限管理 -> 后台弹出界面"中单独授权，请检查',
      ));
    } catch (e) {
      items.add(DiagnosisItem(
        name: '后台弹出界面权限检查',
        status: DiagnosisStatus.warning,
        detail: '检查异常（可能此 ROM 无此权限）: $e',
      ));
    }

    // 5. 通过 MethodChannel 检查原生层通知通道是否已创建
    try {
      const channel = MethodChannel('com.isitenough.app/diagnosis');
      final channelsExist = await channel.invokeMethod<bool>(
        'checkNotificationChannelsExist',
        {'channelIds': ['reminder_strong', 'reminder_soft']},
      );
      items.add(DiagnosisItem(
        name: '原生通知通道创建状态',
        status: channelsExist == true
            ? DiagnosisStatus.ok
            : DiagnosisStatus.error,
        detail: '通道存在性：$channelsExist',
        suggestion: channelsExist != true
            ? '⚠️ 原生通知通道未创建，请检查 MainActivity.kt 是否正确初始化'
            : null,
      ));
    } catch (e) {
      items.add(DiagnosisItem(
        name: '原生通知通道检查',
        status: DiagnosisStatus.warning,
        detail: '原生检查未实现或失败: $e',
      ));
    }

    logger.info('=== 权限诊断完成，共 ${items.length} 项 ===', tag: 'PermissionDiag');

    return PermissionDiagnosisReport(
      platform: 'Android',
      items: items,
    );
  }
}

/// 诊断报告。
class PermissionDiagnosisReport {
  final String platform;
  final List<DiagnosisItem> items;

  PermissionDiagnosisReport({
    required this.platform,
    required this.items,
  });

  int get errorCount =>
      items.where((i) => i.status == DiagnosisStatus.error).length;
  int get warningCount =>
      items.where((i) => i.status == DiagnosisStatus.warning).length;
  int get okCount => items.where((i) => i.status == DiagnosisStatus.ok).length;

  bool get hasError => errorCount > 0;
  bool get hasWarning => warningCount > 0;
  bool get allOk => !hasError && !hasWarning;

  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('## 权限诊断报告\n');
    buf.writeln('平台：$platform');
    buf.writeln('✅ 正常：$okCount 项  ⚠️ 警告：$warningCount 项  ❌ 错误：$errorCount 项\n');
    buf.writeln('---\n');

    for (final item in items) {
      final icon = item.status == DiagnosisStatus.ok
          ? '✅'
          : item.status == DiagnosisStatus.warning
              ? '⚠️'
              : '❌';
      buf.writeln('$icon **${item.name}**');
      buf.writeln('   ${item.detail}');
      if (item.suggestion != null) {
        buf.writeln('   💡 建议：${item.suggestion}');
      }
      buf.writeln('');
    }

    return buf.toString();
  }
}

/// 单个诊断项。
class DiagnosisItem {
  final String name;
  final DiagnosisStatus status;
  final String detail;
  final String? suggestion;

  DiagnosisItem({
    required this.name,
    required this.status,
    required this.detail,
    this.suggestion,
  });
}

enum DiagnosisStatus {
  ok,
  warning,
  error,
}
