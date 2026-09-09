import 'package:flutter/material.dart';

/// 弱提醒：屏幕上方轻量悬浮 Card。
///
/// 不阻断当前操作，只提供倒计时与轻提示。
/// 该组件既可嵌入 Overlay 小窗，也可用于 App 内预览。
class WeakReminderView extends StatefulWidget {
  const WeakReminderView({
    super.key,
    required this.appName,
    required this.snoozeMinutes,
    required this.onSnooze,
    required this.onPutDown,
    this.onClose,
  });

  /// 当前触发提醒的应用名称（如“微信”），拿不到时回退为包名。
  final String appName;

  /// 本次"再刷"的分钟数（正常 5 分钟，连续 3 次后为 2 分钟）。
  final int snoozeMinutes;

  /// 点击"再刷 X 分钟"。
  final VoidCallback onSnooze;

  /// 点击"现在放下"。
  final VoidCallback onPutDown;

  /// 关闭当前提醒（不重置会话）。
  final VoidCallback? onClose;

  @override
  State<WeakReminderView> createState() => _WeakReminderViewState();
}

class _WeakReminderViewState extends State<WeakReminderView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0)),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(_slideAnimation),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xF21C1B20),
                  Color(0xF2242330),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF9ED8C4).withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFF9ED8C4).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: Opacity(
                            opacity: value,
                            child: const Icon(
                              Icons.spa_outlined,
                              color: Color(0xFF9ED8C4),
                              size: 22,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '够了吗？',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Colors.white54,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '你已经在 ${widget.appName} 上停留一段时间了',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '休息一下，让眼睛放松片刻',
                  style: TextStyle(
                    color: const Color(0xFF9ED8C4).withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: widget.onSnooze,
                        child: Text(widget.snoozeMinutes == 0 ? '再刷 30 秒' : '再刷 ${widget.snoozeMinutes} 分钟'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF9ED8C4),
                          foregroundColor: const Color(0xFF101010),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 4,
                          shadowColor: const Color(0xFF9ED8C4).withValues(alpha: 0.4),
                        ),
                        onPressed: widget.onPutDown,
                        child: const Text(
                          '现在放下',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
