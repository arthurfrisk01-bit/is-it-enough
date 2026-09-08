import 'package:flutter/material.dart';
import 'package:is_it_enough/shared/services/statistics_service.dart';
import 'package:provider/provider.dart';

/// 统计首屏。
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatisticsService>(
      builder: (context, statsService, _) {
        final stats = statsService.stats;
        final total = stats.totalTriggers;
        final putDown = stats.putDownCount;
        final continueCount = stats.continueCount;

        final putDownRate =
            total > 0 ? (putDown / total * 100).toStringAsFixed(1) : '0.0';

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildIntro(),
            const SizedBox(height: 16),
            _StatsCard(
              icon: Icons.touch_app_outlined,
              label: '累计触发',
              value: total.toString(),
              color: const Color(0xFF9ED8C4),
            ),
            const SizedBox(height: 12),
            _StatsCard(
              icon: Icons.check_circle_outline,
              label: '现在放下',
              value: putDown.toString(),
              color: const Color(0xFF8EC5FC),
            ),
            const SizedBox(height: 12),
            _StatsCard(
              icon: Icons.schedule_outlined,
              label: '再刷一会',
              value: continueCount.toString(),
              color: const Color(0xFFFFD89C),
            ),
            const SizedBox(height: 12),
            _StatsCard(
              icon: Icons.insights_outlined,
              label: '放下率',
              value: '$putDownRate%',
              color: const Color(0xFFBB9FE8),
            ),
            if (stats.lastTriggerTime != null) ...[
              const SizedBox(height: 16),
              _LastTriggerInfo(time: stats.lastTriggerTime!),
            ],
            const SizedBox(height: 24),
            _buildResetButton(context, statsService),
          ],
        );
      },
    );
  }

  Widget _buildIntro() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '统计数据本地保存，不上传任何云端',
        style: TextStyle(fontSize: 14, color: Colors.white60),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context, StatisticsService service) {
    return TextButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('重置统计'),
            content: const Text('将清空所有统计数据，此操作不可恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('重置'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await service.reset();
        }
      },
      icon: const Icon(Icons.refresh),
      label: const Text('重置统计'),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastTriggerInfo extends StatelessWidget {
  const _LastTriggerInfo({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(time);

    String displayText;
    if (diff.inDays > 0) {
      displayText = '${diff.inDays} 天前';
    } else if (diff.inHours > 0) {
      displayText = '${diff.inHours} 小时前';
    } else if (diff.inMinutes > 0) {
      displayText = '${diff.inMinutes} 分钟前';
    } else {
      displayText = '刚刚';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.history, size: 20, color: Colors.white54),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '上次触发',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
