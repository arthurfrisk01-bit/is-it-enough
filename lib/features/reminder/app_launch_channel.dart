import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:is_it_enough/core/navigation/app_navigator.dart';
import 'package:is_it_enough/features/breathing/breathing_page.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';

/// 与原生 `AppLaunchBridge` 通信：把 App 拉到前台 + 打开呼吸引导页。
///
/// 背景（2026-09 实机 bug）：“现在放下”过去直接
/// `appNavigatorKey.currentState.push(BreathingPage)`：
/// - 界面引擎在后台时，push 只是把路由压到后台导航栈上，用户看不到，
///   等自己切回 App 才“突然”弹出呼吸页；
/// - 后台 headless 引擎处理点击时根本没有 Navigator，整段逻辑直接 return。
///
/// 现在统一交给原生：原生把 MainActivity 拉到前台，再回传 `openBreathing`
/// 给界面引擎；冷启动时由 [consumePendingAction] 补取。
class AppLaunchChannel {
  AppLaunchChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.isitenough.app/launch');

  /// 防止原生回传与冷启动补取同时命中，导致呼吸页被推两次。
  static bool _opening = false;
  static int _lastOpenMs = 0;

  /// 在界面引擎初始化时调用一次。
  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openBreathing') {
        openBreathingPage();
      }
      return null;
    });
    unawaited(consumePendingAction());
  }

  /// 冷启动补取原生攒下的动作。
  static Future<void> consumePendingAction() async {
    try {
      final action = await _channel.invokeMethod<String>('consumePendingAction');
      if (action == 'openBreathing') openBreathingPage();
    } catch (_) {
      // 非 Android / 原生未注册：静默忽略。
    }
  }

  /// 请求把 App 拉到前台并打开呼吸页。
  static Future<void> requestOpenBreathingPage() async {
    try {
      await _channel.invokeMethod<void>('openApp', {'openBreathing': true});
    } catch (e) {
      LoggerService().warning('拉起 App 到前台失败: $e，回退到本进程内跳转', tag: 'Launch');
      openBreathingPage();
    }
  }

  /// 在界面引擎里打开呼吸页（去重，避免重复弹出）。
  static void openBreathingPage() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_opening || nowMs - _lastOpenMs < 1500) return;
    _opening = true;
    _lastOpenMs = nowMs;
    navigator
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => const BreathingPage(),
          ),
        )
        .whenComplete(() => _opening = false);
  }
}
