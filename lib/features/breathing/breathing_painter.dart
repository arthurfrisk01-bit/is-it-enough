import 'package:flutter/material.dart';

/// 呼吸圆环绘制器。
///
/// 一个周期 [BreathingPainter.cycleDuration] 共 8 秒：
/// - 前 4 秒（phase 0.0 -> 0.5）为吸气，圆环缓慢扩张；
/// - 后 4 秒（phase 0.5 -> 1.0）为呼气，圆环缓慢收缩。
///
/// [phase] 来自 AnimationController 的 0.0 ~ 1.0 值。
class BreathingPainter extends CustomPainter {
  const BreathingPainter({
    required this.phase,
    required this.color,
    this.background = const Color(0xFF000000),
  });

  /// 0.0 ~ 1.0 的呼吸相位。
  final double phase;

  /// 主圆环颜色（低饱和青绿色，避免刺激）。
  final Color color;

  /// 页面背景色。
  final Color background;

  static const Duration cycleDuration = Duration(seconds: 8);

  /// 是否处于吸气阶段。
  bool get isInhale => phase < 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide * 0.42;

    // 阶段进度：0~0.5 吸，0.5~1 呼。
    final local = isInhale ? phase * 2 : (phase - 0.5) * 2;
    // 使用 easeInOut 使呼吸更自然。
    final t = Curves.easeInOut.transform(local);

    // 背景层：极淡的大圆，提供“存在感”但不抢注意力。
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius * 1.25, bgPaint);

    // 外圈辅助光环。
    final outerPaint = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, maxRadius * (0.85 + t * 0.35), outerPaint);

    // 主脉动圆环。
    final mainPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final mainRadius = maxRadius * (0.35 + t * 0.55);
    canvas.drawCircle(center, mainRadius, mainPaint);

    // 内芯：吸气时稍亮，呼气时暗淡，形成“我在呼吸”的暗示。
    final corePaint = Paint()
      ..color = color.withValues(alpha: isInhale ? 0.12 + t * 0.08 : 0.20 - t * 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, mainRadius * 0.38, corePaint);
  }

  @override
  bool shouldRepaint(covariant BreathingPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.color != color;
  }
}
