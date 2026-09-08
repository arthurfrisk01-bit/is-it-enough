import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:is_it_enough/features/breathing/breathing_painter.dart';

/// 强提醒：全屏毛玻璃遮罩 + 呼吸动画，强力中断当前操作。
///
/// 默认作为全局 Overlay 或全屏页面展示。
class StrongReminderView extends StatefulWidget {
  const StrongReminderView({
    super.key,
    required this.packageName,
    required this.snoozeMinutes,
    required this.onSnooze,
    required this.onPutDown,
  });

  final String packageName;
  final int snoozeMinutes;
  final VoidCallback onSnooze;
  final VoidCallback onPutDown;

  @override
  State<StrongReminderView> createState() => _StrongReminderViewState();
}

class _StrongReminderViewState extends State<StrongReminderView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: BreathingPainter.cycleDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.86),
              const Color(0xFF101218).withValues(alpha: 0.94),
              Colors.black.withValues(alpha: 0.96),
            ],
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 呼吸脉动动画背景。
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: BreathingPainter(
                      phase: _controller.value,
                      color: const Color(0xFF9ED8C4),
                    ),
                  );
                },
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // 标题区。
                      const Text(
                        '够了吗',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '你已经在 ${widget.packageName} 上停留太久',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '先停一下，跟随圆环呼吸',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),

                      const Spacer(flex: 3),

                      // 操作区。
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF9ED8C4),
                            foregroundColor: const Color(0xFF101010),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: widget.onPutDown,
                          child: const Text('现在放下'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          onPressed: widget.onSnooze,
                          child: Text('再刷 ${widget.snoozeMinutes} 分钟'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '提示：连续选择“再刷”超过 3 次，等待时间会缩短',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
