import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/features/reminder/overlay_window_service.dart';
import 'package:is_it_enough/features/reminder/strong_reminder_view.dart';
import 'package:is_it_enough/features/reminder/weak_reminder_view.dart';

/// 全局 Overlay 内实际展示的根组件。
///
/// 该组件运行在 `flutter_overlay_window` 拉起的独立 Flutter 引擎中，
/// 通过 `FlutterOverlayWindow.overlayListener` 接收主 App 发来的数据。
///
/// 这个隔离区没有注册原生日志桥（引擎由插件自己创建），所以关键事件都用
/// `shareData` 回传主 App 落盘，日志里会以 `[Overlay]` 前缀出现。
class OverlayHost extends StatefulWidget {
  const OverlayHost({super.key});

  @override
  State<OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<OverlayHost> {
  StreamSubscription<dynamic>? _subscription;
  Timer? _readyPing;
  bool _pinging = false;

  String? _mode;
  String _packageName = '';
  String _appName = '';
  int _snoozeMinutes = 5;

  /// 只回执一次“内容已渲染”，避免重复刷屏。
  bool _ackSent = false;

  @override
  void initState() {
    super.initState();

    _subscription = FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted || data is! Map) return;
      // 带 action 的是主 App 的控制消息，不是提醒数据。
      if (data['action'] != null) return;
      final firstPayload = _packageName.isEmpty;
      setState(() {
        _mode = data['mode'] as String? ?? _mode;
        _packageName = data['packageName'] as String? ?? _packageName;
        _appName = data['appName'] as String? ?? _appName;
        _snoozeMinutes = data['snoozeMinutes'] as int? ?? _snoozeMinutes;
      });
      _readyPing?.cancel();
      if (firstPayload) {
        _relay('Overlay 收到提醒数据：$_packageName 模式=$_mode');
      }
      _ackShown();
    });

    // Overlay 引擎可能比主 App 推送数据晚好几秒才就绪（2026-09-09 实机：
    // shareData 连续两次超时，数据很久之后才被处理，窗口一直是空白的）。
    // 这里在“窗口真的开始渲染”之后向主 App 喊 overlayReady，主 App 收到后把
    // 暂存的提醒数据补发过来。用帧回调而不是纯定时器：没有窗口、没有帧的时候
    // 不该喊话（否则 App 一启动就白喊一轮）。
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  void _onFrame(Duration _) {
    if (_packageName.isNotEmpty || _pinging) return;
    _pinging = true;
    var ticks = 0;
    _readyPing = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted || _packageName.isNotEmpty || ++ticks > 6) {
        timer.cancel();
        _pinging = false;
        return;
      }
      unawaited(
        OverlayWindowService.sendData({'action': 'overlayReady', 'tick': ticks}),
      );
    });
  }

  /// 回传给主 App 的一行日志（本隔离区没有原生日志桥）。
  void _relay(String message) {
    unawaited(OverlayWindowService.sendData({'action': 'log', 'msg': message}));
  }

  /// 回执给主引擎：悬浮窗内容已经真正渲染出来。
  ///
  /// 主引擎只有在收到该回执后才认定悬浮窗可用；收不到就立刻关掉窗口，
  /// 避免一个透明空窗压在应用上导致整屏点不动。
  void _ackShown() {
    if (_ackSent || _packageName.isEmpty) return;
    _ackSent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 内容画出来了才把窗口从“点击穿透”切成可点击；切换失败就不回执，
      // 让主 App 3.5s 后关掉这个窗口（通知已经发过，用户不会漏提醒）。
      final interactive = await OverlayWindowService.makeInteractive();
      if (!interactive) {
        _relay('Overlay 切换可点击失败，放弃本次悬浮窗');
        return;
      }
      await OverlayWindowService.sendData({
        'action': 'overlayShown',
        'mode': _mode,
        'packageName': _packageName,
      });
      _relay('Overlay 渲染回执已发出（$_packageName）');
    });
  }

  @override
  void dispose() {
    _readyPing?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  ReminderMode get _reminderMode =>
      ReminderMode.fromStorage(_mode ?? ReminderMode.strong.storageKey);

  /// 展示给用户的应用名：优先真实应用名，拿不到时回退包名。
  String get _displayName => _appName.isNotEmpty ? _appName : _packageName;

  Future<void> _snooze() async {
    await OverlayWindowService.sendData({'action': 'snooze'});
    await OverlayWindowService.hide();
  }

  Future<void> _putDown() async {
    await OverlayWindowService.sendData({'action': 'putDown'});
    await OverlayWindowService.hide();
  }

  @override
  Widget build(BuildContext context) {
    // 还没收到数据：保持完全透明。
    //
    // 此时窗口是“点击穿透”的（见 OverlayWindowService.show），既看不见也点不动，
    // 不会挡住下面的应用。旧版本这里画了一个 90% 不透明的深色占位，在引擎没起来
    // 的情况下会变成一块莫名其妙的黑窗。
    if (_packageName.isEmpty) {
      return const SizedBox.expand();
    }

    final mode = _reminderMode;
    if (mode == ReminderMode.strong) {
      return StrongReminderView(
        appName: _displayName,
        snoozeMinutes: _snoozeMinutes,
        onSnooze: _snooze,
        onPutDown: _putDown,
      );
    }

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: WeakReminderView(
              appName: _displayName,
              snoozeMinutes: _snoozeMinutes,
              onSnooze: _snooze,
              onPutDown: _putDown,
            ),
          ),
        ),
      ),
    );
  }
}
