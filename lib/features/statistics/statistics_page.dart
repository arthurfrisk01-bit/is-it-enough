import 'package:flutter/material.dart';
import 'package:is_it_enough/features/statistics/domain/usage_report.dart';
import 'package:is_it_enough/shared/services/statistics_service.dart';
import 'package:provider/provider.dart';

/// 统计首屏：概览数字 + 今日使用量 + 使用时间线。
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  @override
  void initState() {
    super.initState();
    // 首帧后再拉数据：refreshUsage 会 notifyListeners，build 期间调用会触发断言。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<StatisticsService>();
      if (!service.usageLoadedOnce && !service.usageLoading) {
        service.refreshUsage();
      }
    });
  }

  Future<void> _refresh() =>
      context.read<StatisticsService>().refreshUsage();

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

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _buildIntro(statsService),
              const SizedBox(height: 12),
              _StatsGrid(
                items: [
                  _StatItem(
                    icon: Icons.touch_app_outlined,
                    label: '累计触发',
                    value: total.toString(),
                    color: const Color(0xFF9ED8C4),
                  ),
                  _StatItem(
                    icon: Icons.check_circle_outline,
                    label: '现在放下',
                    value: putDown.toString(),
                    color: const Color(0xFF8EC5FC),
                  ),
                  _StatItem(
                    icon: Icons.schedule_outlined,
                    label: '再刷一会',
                    value: continueCount.toString(),
                    color: const Color(0xFFFFD89C),
                  ),
                  _StatItem(
                    icon: Icons.insights_outlined,
                    label: '放下率',
                    value: '$putDownRate%',
                    color: const Color(0xFFBB9FE8),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _UsageSection(service: statsService),
              const SizedBox(height: 20),
              _TimelineSection(service: statsService),
              if (stats.lastTriggerTime != null) ...[
                const SizedBox(height: 20),
                _LastTriggerInfo(time: stats.lastTriggerTime!),
              ],
              const SizedBox(height: 24),
              _buildResetButton(context, statsService),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntro(StatisticsService service) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '统计数据本地保存，不上传任何云端',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ),
        if (service.usageLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            tooltip: '刷新使用数据',
            visualDensity: VisualDensity.compact,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
      ],
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

// ---------------------------------------------------------------- 概览数字

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});

  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 12));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StatsCard(item: items[i])),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < items.length
                    ? _StatsCard(item: items[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              item.value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- 今日使用量

class _UsageSection extends StatelessWidget {
  const _UsageSection({required this.service});

  final StatisticsService service;

  @override
  Widget build(BuildContext context) {
    final report = service.usageReport;

    return _SectionCard(
      title: '今日使用量',
      icon: Icons.bar_chart_rounded,
      trailing: report == null
          ? null
          : Text(
              formatUsageDuration(report.totalUsage),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9ED8C4),
                fontWeight: FontWeight.w600,
              ),
            ),
      child: _buildBody(context, report),
    );
  }

  Widget _buildBody(BuildContext context, UsageReport? report) {
    if (service.usageError == 'NO_PERMISSION') {
      return const _HintText('需要“使用情况访问”权限才能统计使用量，请在设置页授权后下拉刷新。');
    }
    if (report == null) {
      return _HintText(
        service.usageLoading ? '正在读取今日使用数据…' : '暂无使用数据，下拉刷新试试。',
      );
    }
    if (report.isEmpty) {
      return const _HintText('今天还没有可统计的应用使用记录。');
    }

    final maxTotal = report.apps.first.total.inMilliseconds;
    final top = report.apps.take(8).toList();
    return Column(
      children: [
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _UsageBarRow(
            app: top[i],
            ratio: maxTotal <= 0 ? 0 : top[i].total.inMilliseconds / maxTotal,
          ),
        ],
      ],
    );
  }
}

class _UsageBarRow extends StatelessWidget {
  const _UsageBarRow({required this.app, required this.ratio});

  final AppUsage app;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                app.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatUsageDuration(app.total),
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 6,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.02, 1.0),
                child: Container(
                  height: 6,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF9ED8C4), Color(0xFF6C8CD5)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- 时间线

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.service});

  final StatisticsService service;

  static const int _maxEntries = 40;

  @override
  Widget build(BuildContext context) {
    final report = service.usageReport;
    final entries = report?.timeline ?? const <TimelineEntry>[];

    return _SectionCard(
      title: '使用时间线',
      icon: Icons.timeline_rounded,
      child: _buildBody(context, entries),
    );
  }

  Widget _buildBody(BuildContext context, List<TimelineEntry> entries) {
    if (service.usageError == 'NO_PERMISSION') {
      return const _HintText('授权“使用情况访问”后，这里会按时间顺序展开今天用过的应用。');
    }
    if (entries.isEmpty) {
      return const _HintText('今天还没有时间线记录。');
    }

    final shown = entries.take(_maxEntries).toList();
    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          _TimelineTile(
            entry: shown[i],
            isFirst: i == 0,
            isLast: i == shown.length - 1,
          ),
        if (entries.length > shown.length)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '仅显示最近 \$_maxEntries 条',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final TimelineEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    const lineColor = Color(0x33FFFFFF);
    final session = entry.session;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧时刻。
          SizedBox(
            width: 46,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                formatClock(session.start),
                style: TextStyle(
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
          ),
          // 竖线 + 节点。
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 4,
                  color: isFirst ? Colors.transparent : lineColor,
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF9ED8C4),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : lineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 右侧内容。
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatClock(session.start)} – ${formatClock(session.end)}'
                    ' · ${formatUsageDuration(session.duration)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- 通用

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF9ED8C4)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        height: 1.5,
        color: Colors.white.withValues(alpha: 0.55),
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
