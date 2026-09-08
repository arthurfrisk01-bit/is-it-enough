import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';
import 'package:provider/provider.dart';

/// 日志查看页。
class LogViewerPage extends StatelessWidget {
  const LogViewerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '复制 Warning 以上',
            onPressed: () => _copyWarningsAndAbove(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: () => _clearLogs(context),
          ),
        ],
      ),
      body: Consumer<LoggerService>(
        builder: (context, logger, _) {
          final logs = logger.logs;
          if (logs.isEmpty) {
            return const Center(
              child: Text(
                '暂无日志',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _LogEntryTile(entry: log);
            },
          );
        },
      ),
    );
  }

  void _copyWarningsAndAbove(BuildContext context) {
    final logger = context.read<LoggerService>();
    final warnings = logger.getWarningsAndAbove();
    if (warnings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有 Warning 以上级别日志')),
      );
      return;
    }
    final text = warnings.map((e) => e.toString()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${warnings.length} 条日志')),
    );
  }

  void _clearLogs(BuildContext context) {
    context.read<LoggerService>().clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志已清空')),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    Color levelColor;
    switch (entry.level) {
      case LogLevel.debug:
        levelColor = Colors.grey;
        break;
      case LogLevel.info:
        levelColor = Colors.blue;
        break;
      case LogLevel.warning:
        levelColor = Colors.orange;
        break;
      case LogLevel.error:
        levelColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.levelText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: levelColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.formattedTime,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.white54,
                  ),
                ),
                if (entry.tag != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '[${entry.tag}]',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.white38,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              entry.message,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
