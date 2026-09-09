import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:is_it_enough/features/breathing/breathing_painter.dart';
import 'package:vibration/vibration.dart';

/// 强提醒：全屏毛玻璃遮罩 + 大号主信息 + 小呼吸圆环，强力中断当前操作。
///
/// 视觉层级（2026-09 大版本调整）：用户最需要立刻看到的是「哪个应用 + 已经用了
/// 多久」，所以应用名/时长占据视觉中心；呼吸圆环缩小到 120dp 作为陪衬，
/// 不再与文字抢注意力。
class StrongReminderView extends StatefulWidget {
  const StrongReminderView({
    super.key,
    required this.appName,
    required this.snoozeMinutes,
    required this.onSnooze,
    required this.onPutDown,
    required this.onFocus,
    this.continuousMinutes = 0,
  });

  final String appName;
  final int snoozeMinutes;

  /// 本次连续使用时长（分钟），用于强调主信息。
  final int continuousMinutes;

  final VoidCallback onSnooze;
  final VoidCallback onPutDown;

  /// “正在专注，1 小时内勿扰”。
  final VoidCallback onFocus;

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
    final minutes = widget.continuousMinutes;

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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // 小标签。
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: child,
                    ),
                    child: Text(
                      '够了吗',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 主信息一：应用名。
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.82 + (value * 0.18),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: Text(
                      widget.appName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(
                            color: Color(0xFF9ED8C4),
                            blurRadius: 28,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 主信息二：已用时长。
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1500),
                    curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: child,
                    ),
                    child: Text(
                      minutes > 0 ? '已连续使用 $minutes 分钟' : '已经停留太久了',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),

                  // 呼吸圆环：缩小到 120dp，只做引导。
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: AnimatedBuilder(
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
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '跟随圆环，慢慢呼吸',
                    style: TextStyle(
                      color: const Color(0xFF9ED8C4).withValues(alpha: 0.6),
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // 操作区。
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1800),
                    curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: child,
                    ),
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
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                            onPressed: widget.onSnooze,
                            child: Text(
                              widget.snoozeMinutes == 0
                                  ? '再刷 30 秒'
                                  : '再刷 ${widget.snoozeMinutes} 分钟',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 专注勿扰：告诉软件自己正在专注，1 小时内不要再打扰。
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  const Color(0xFF9ED8C4).withValues(alpha: 0.9),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: widget.onFocus,
                            icon: const Icon(Icons.do_not_disturb_on_outlined, size: 18),
                            label: const Text(
                              '正在专注，1 小时内勿扰',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
