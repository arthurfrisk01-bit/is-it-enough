import 'package:flutter/material.dart';

/// 弱提醒：屏幕上方轻量悬浮 Card。
///
/// 不阻断当前操作，只提供倒计时与轻提示。
/// 该组件既可嵌入 Overlay 小窗，也可用于 App 内预览。
class WeakReminderView extends StatelessWidget {
  const WeakReminderView({
    super.key,
    required this.packageName,
    required this.snoozeMinutes,
    required this.onSnooze,
    required this.onPutDown,
    this.onClose,
  });

  /// 当前触发提醒的应用包名。
  final String packageName;

  /// 本次“再刷”的分钟数（正常 5 分钟，连续 3 次后为 2 分钟）。
  final int snoozeMinutes;

  /// 点击“再刷 X 分钟”。
  final VoidCallback onSnooze;

  /// 点击“现在放下”。
  final VoidCallback onPutDown;

  /// 关闭当前提醒（不重置会话）。
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xF21C1B20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spa_outlined,
                    color: Color(0xFF9ED8C4), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '够了吗？',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '你已经在 $packageName 上停留一段时间了',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSnooze,
                    child: Text('再刷 $snoozeMinutes 分钟'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF9ED8C4),
                      foregroundColor: const Color(0xFF101010),
                    ),
                    onPressed: onPutDown,
                    child: const Text('现在放下'),
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
