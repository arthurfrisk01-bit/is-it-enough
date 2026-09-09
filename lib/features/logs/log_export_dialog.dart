import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:is_it_enough/shared/services/log_export_service.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:is_it_enough/shared/services/statistics_service.dart';
import 'package:provider/provider.dart';

/// 一键导出全量日志（系统快照 + 跨引擎落盘日志 + 当前内存日志）。
///
/// 设置页和日志页共用同一套流程：进度框 → 保存到下载目录 → 结果框
/// （显示路径、自动比对出的可疑点，并提供分享 / 复制）。
Future<void> exportAndShowLogs(BuildContext context) async {
  final logger = context.read<LoggerService>();
  final settings = context.read<SettingsService>();
  final statistics = context.read<StatisticsService>();
  final messenger = ScaffoldMessenger.of(context);

  logger.info('开始导出全量日志', tag: 'LogExport');

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('正在收集日志与系统状态...')),
        ],
      ),
    ),
  );

  try {
    final result = await const LogExportService().exportAndSave(
      settings: settings,
      statistics: statistics,
    );
    logger.info('日志已导出到 ${result.path}（${result.bytes} 字符）', tag: 'LogExport');

    if (!context.mounted) return;
    Navigator.of(context).pop(); // 关闭进度框
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出完成'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '文件：${result.path}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (result.hints.isEmpty)
                  const Text('自动比对未发现明显异常项。')
                else ...[
                  const Text(
                    '自动比对发现的可疑点：',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  ...result.hints.map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '• $h',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFFB74D),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  '共 ${result.bytes} 字符，含系统快照、全部落盘日志与当前内存日志。',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await const LogExportService().share(result);
              messenger.showSnackBar(
                SnackBar(content: Text(ok ? '已打开分享面板' : '分享失败，请手动到下载目录取文件')),
              );
            },
            child: const Text('分享'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: result.content));
              messenger.showSnackBar(
                const SnackBar(content: Text('完整日志已复制到剪贴板')),
              );
            },
            child: const Text('复制全部'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  } catch (e) {
    logger.error('导出日志异常: $e', tag: 'LogExport');
    if (context.mounted) {
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }
}
