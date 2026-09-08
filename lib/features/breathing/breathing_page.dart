import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:is_it_enough/features/breathing/breathing_painter.dart';
import 'package:vibration/vibration.dart';

/// 全屏呼吸引导页。
///
/// 设计目标：
/// - 纯黑背景、低亮度 UI，帮助用户真正“放下手机”；
/// - 4 秒吸气 / 4 秒呼气，持续 5 分钟；
/// - 阶段切换时提供轻微震动反馈。
///
/// Android 强提醒选择“现在放下”后，以及 iOS 用户主动开始专注时，
/// 都会进入本页面。
class BreathingPage extends StatefulWidget {
  const BreathingPage({
    super.key,
    this.totalDuration = const Duration(minutes: 5),
    this.onFinished,
  });

  /// 总专注时长，默认 5 分钟。
  final Duration totalDuration;

  /// 倒计时自然结束后的回调。
  final VoidCallback? onFinished;

  @override
  State<BreathingPage> createState() => _BreathingPageState();
}

class _BreathingPageState extends State<BreathingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _countdownTimer;

  Duration _remaining = Duration.zero;
  bool _vibratedForInhale = false;
  bool _vibratedForExhale = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalDuration;

    _controller = AnimationController(
      vsync: this,
      duration: BreathingPainter.cycleDuration,
    )..repeat();

    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining - const Duration(seconds: 1);
      });

      if (_remaining <= Duration.zero) {
        timer.cancel();
        widget.onFinished?.call();
        if (mounted) Navigator.of(context).maybePop();
      }
    });
  }

  String get _remainingText {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _maybeVibrateOnPhaseChange() async {
    final isInhale = _controller.value < 0.5;

    // 仅在新阶段开始时震动一次。
    if (isInhale && !_vibratedForInhale) {
      _vibratedForInhale = true;
      _vibratedForExhale = false;
      await _safeVibrate();
    } else if (!isInhale && !_vibratedForExhale) {
      _vibratedForExhale = true;
      _vibratedForInhale = false;
      await _safeVibrate();
    }
  }

  Future<void> _safeVibrate() async {
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 80);
      }
    } catch (_) {
      // 部分模拟器/低端机无震动器，静默忽略。
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 呼吸动画主体。
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  // 在构建周期里安排震动检测，避免 build 中直接 async 调用。
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    _maybeVibrateOnPhaseChange();
                  });
                  return CustomPaint(
                    painter: BreathingPainter(
                      phase: _controller.value,
                      color: const Color(0xFF9ED8C4),
                    ),
                  );
                },
              ),
            ),

            // 顶部：标题与倒计时。
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  const Text(
                    '够了吗',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _remainingText,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),

            // 底部：阶段文字与退出按钮。
            Positioned(
              left: 24,
              right: 24,
              bottom: 32,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final inhale = _controller.value < 0.5;
                      return Text(
                        inhale ? '慢慢吸气' : '缓缓呼气',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '把手机放在一旁，跟随圆环呼吸',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('提前结束'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white38,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
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
