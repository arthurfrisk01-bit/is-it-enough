import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:is_it_enough/features/breathing/breathing_painter.dart';
import 'package:vibration/vibration.dart';

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
    _triggerVibration();
  }

  Future<void> _triggerVibration() async {
    try {
      // 触发提醒时震动提示（强提醒专属）
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(
          pattern: [0, 400, 200, 400],
          intensities: [0, 200, 0, 255],
        );
      }
    } catch (e) {
      // 震动失败不阻断提醒
    }
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
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: 0.7 + (value * 0.3),
                            child: Opacity(
                              opacity: value,
                              child: const Text(
                                '够了吗',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 6,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xFF9ED8C4),
                                      blurRadius: 24,
                                      offset: Offset(0, 0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1500),
                        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Column(
                              children: [
                                Text(
                                  '你已经在 ${widget.packageName} 上停留太久',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '先停一下，跟随圆环呼吸',
                                  style: TextStyle(
                                    color: const Color(0xFF9ED8C4).withValues(alpha: 0.6),
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const Spacer(flex: 3),

                      // 操作区。
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1800),
                        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF9ED8C4),
                                      foregroundColor: const Color(0xFF101010),
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      textStyle: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                      elevation: 8,
                                      shadowColor: const Color(0xFF9ED8C4),
                                    ),
                                    onPressed: widget.onPutDown,
                                    child: const Text('现在放下'),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                      ),
                                    ),
                                    onPressed: widget.onSnooze,
                                    child: Text(widget.snoozeMinutes == 0 ? '再刷 30 秒' : '再刷 ${widget.snoozeMinutes} 分钟'),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  '提示：连续选择“再刷”超过 3 次，等待时间会缩短',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
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
