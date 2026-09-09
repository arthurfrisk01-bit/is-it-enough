import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:is_it_enough/shared/services/statistics_service.dart';

/// 一次日志导出的结果。
class LogExportResult {
  const LogExportResult({
    required this.path,
    required this.uri,
    required this.content,
    required this.hints,
  });

  /// 落盘路径（下载目录，或应用外部目录兜底）。
  final String path;

  /// 可直接分享的 content:// URI（Android 10+ 有值）。
  final String? uri;

  /// 完整导出文本（含全部日志与系统快照）。
  final String content;

  /// 自动推断出的可疑点。
  final List<String> hints;

  int get bytes => content.length;
}

/// 日志导出服务：把“所有日志 + 系统实时响应”合成一份 txt 文件。
///
/// 内容分五段：
/// 1. 结论速查（自动比对系统状态得出的可疑点）
/// 2. 系统状态快照（原生实时采集：权限 / 通知通道 / 省电 / 服务 / 进程）
/// 3. 当前设置与统计
/// 4. 原生日志文件（界面引擎 + 后台引擎 + 原生服务，全量跨引擎日志）
/// 5. 当前引擎内存日志（最近 2000 条）
class LogExportService {
  const LogExportService();

  static const MethodChannel _logChannel = MethodChannel('com.isitenough.app/log');

  /// 生成报告并保存到系统“下载”目录，返回路径与可分享 URI。
  Future<LogExportResult> exportAndSave({
    SettingsService? settings,
    StatisticsService? statistics,
  }) async {
    final content = await buildReport(settings: settings, statistics: statistics);
    final name = 'isitenough-log-${_stamp()}.txt';
    var path = '';
    String? uri;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final saved = await _logChannel.invokeMethod<Map<dynamic, dynamic>>(
          'export',
          {'content': content, 'name': name},
        );
        path = (saved?['path'] as String?) ?? '';
        uri = saved?['uri'] as String?;
      } catch (e) {
        LoggerService().error('导出日志失败: $e', tag: 'LogExport');
      }
    }
    return LogExportResult(
      path: path.isEmpty ? '（未保存到文件，可复制文本）' : path,
      uri: uri,
      content: content,
      hints: extractHints(content),
    );
  }

  /// 只生成报告文本，不落盘。
  Future<String> buildReport({
    SettingsService? settings,
    StatisticsService? statistics,
  }) async {
    final logger = LoggerService();
    final buf = StringBuffer();

    buf.writeln('================ 够了吗 调试日志导出 ================');
    buf.writeln('生成时间: ${_fullTime()}');
    buf.writeln('来源引擎: ${LoggerService.isolateName}');
    buf.writeln('日志页内存条数: ${logger.logs.length}');
    buf.writeln();

    // 1. 系统快照（原生实时采集）
    var diagnostics = '';
    if (!kIsWeb && Platform.isAndroid) {
      try {
        diagnostics = await _logChannel.invokeMethod<String>('diagnostics') ?? '';
      } catch (e) {
        diagnostics = '[采集失败] $e';
      }
    } else {
      diagnostics = '[非 Android 平台，跳过系统快照]';
    }

    buf.writeln('########## 1. 系统状态快照（实时采集） ##########');
    buf.writeln(diagnostics.trim());
    buf.writeln();

    final hints = extractHints(diagnostics);
    buf.writeln('########## 2. 结论速查（自动比对） ##########');
    if (hints.isEmpty) {
      buf.writeln('未发现明显异常项（系统侧权限/通道/服务看起来正常）。');
    } else {
      for (final h in hints) {
        buf.writeln('• $h');
      }
    }
    buf.writeln();

    // 3. 当前设置与统计
    buf.writeln('########## 3. 当前设置与统计 ##########');
    if (settings != null) {
      buf.writeln('监控开关: ${settings.monitoringEnabled}');
      buf.writeln('提醒模式: ${settings.reminderMode.name}');
      buf.writeln('连续使用阈值: ${settings.thresholdMinutes} 分钟');
      buf.writeln('智能消抖: ${settings.debounceEnabled}');
      buf.writeln('调试模式: ${settings.debugMode}');
      buf.writeln('黑名单包数: ${settings.blacklistedPackageNames.length}');
      buf.writeln('黑名单: ${settings.blacklistedPackageNames.join(", ")}');
    } else {
      buf.writeln('（未传入设置服务）');
    }
    if (statistics != null) {
      final s = statistics.stats;
      buf.writeln('累计触发: ${s.totalTriggers} 次');
      buf.writeln('选择放下: ${s.putDownCount} 次');
      buf.writeln('选择继续: ${s.continueCount} 次');
      buf.writeln('最近触发: ${s.lastTriggerTime ?? "无"}');
    } else {
      buf.writeln('（未传入统计服务）');
    }
    buf.writeln();

    // 4. 原生日志文件（跨引擎全量）
    var nativeLog = '';
    if (!kIsWeb && Platform.isAndroid) {
      try {
        nativeLog = await _logChannel.invokeMethod<String>('read') ?? '';
      } catch (e) {
        nativeLog = '[读取失败] $e';
      }
    }
    buf.writeln('########## 4. 原生日志文件（全量，含后台引擎） ##########');
    buf.writeln(nativeLog.trim().isEmpty ? '（暂无落盘日志）' : nativeLog.trim());
    buf.writeln();

    // 5. 当前引擎内存日志
    buf.writeln('########## 5. 当前引擎内存日志（最近 2000 条） ##########');
    final memory = logger.fullText();
    buf.writeln(memory.isEmpty ? '（暂无）' : memory);
    buf.writeln();
    buf.writeln('================ 导出结束 ================');

    return buf.toString();
  }

  /// 分享已导出的日志文件（无 URI 时分享文本）。
  Future<bool> share(LogExportResult result) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await _logChannel.invokeMethod<bool>('share', {
            'uri': result.uri,
            'text': result.content,
          }) ??
          false;
    } catch (e) {
      LoggerService().error('分享日志失败: $e', tag: 'LogExport');
      return false;
    }
  }

  /// 从系统快照里挑出会导致“通知不弹”的可疑项。
  static List<String> extractHints(String diagnostics) {
    final hints = <String>[];
    void check(String needle, String message) {
      if (diagnostics.contains(needle)) hints.add(message);
    }

    check('通知总开关(areNotificationsEnabled): false',
        '系统通知总开关被关闭 —— 去 系统设置→应用→够了吗→通知 打开');
    check(': 不存在（未创建！）', '存在未创建的通知通道 —— 通道创建失败，重启应用或重装');
    check('重要性=NONE(已关闭)', '有通知通道被用户设为“关闭” —— 在通知设置里把对应通道打开');
    check('POST_NOTIFICATIONS: false', 'POST_NOTIFICATIONS 权限被拒绝（Android 13+）');
    check('全屏通知可用(canUseFullScreenIntent): false',
        '系统未允许“全屏通知” —— 强提醒会降级为横幅，可在 通知设置→全屏通知 开启');
    check('PACKAGE_USAGE_STATS: false', '没有“使用情况访问”权限 —— 监控读不到前台应用，永远不会触发提醒');
    check('SYSTEM_ALERT_WINDOW(悬浮窗): false', '没有悬浮窗权限 —— 强提醒悬浮窗不可用（系统通知仍可用）');
    check('忽略电池优化: false', '未加入电池优化白名单 —— 后台容易被系统冻结，建议设为“无限制/不优化”');
    check('省电模式: true', '系统处于省电模式 —— 通知和后台容易被限制');
    check('保活服务运行中: false', '后台保活服务没在跑 —— 离开应用后监控会停，检查“后台监控”开关');
    check('headless 引擎存活: false', '后台无界面引擎未运行（App 界面在时不需）—— 若界面已关闭则后台监控已停');
    check('Doze 待机: true', '设备处于 Doze 深度待机 —— 后台提醒会被延迟');
    check('进程重要性: CACHED', '进程处于可回收状态 —— 后台随时可能被杀');
    check('前台查询失败：未授予', '前台应用查询失败：使用情况访问权限未授予');
    check('前台查询异常', '前台应用查询抛异常（详见下方日志）');
    check('Overlay 复核：渲染回执=false', '悬浮窗未回执渲染完成（服务在跑但窗口没画出来）——已改为自动发送完整通知兜底');
    check('通知已提交但系统未保留', '通知被系统丢弃 —— 检查通知权限与该通道是否被关闭');
    check('Overlay 展示异常', '悬浮窗展示抛异常（详见日志）');
    return hints;
  }

  static String _stamp() {
    final t = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${p(t.month)}${p(t.day)}-${p(t.hour)}${p(t.minute)}${p(t.second)}';
  }

  static String _fullTime() {
    final t = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${p(t.month)}-${p(t.day)} ${p(t.hour)}:${p(t.minute)}:${p(t.second)}';
  }
}
