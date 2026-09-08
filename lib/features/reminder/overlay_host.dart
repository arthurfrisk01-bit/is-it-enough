import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/features/reminder/overlay_window_service.dart';
import 'package:is_it_enough/features/reminder/strong_reminder_view.dart';
import 'package:is_it_enough/features/reminder/weak_reminder_view.dart';

/// 全局 Overlay 内实际展示的根组件。
///
/// 该组件运行在 `flutter_overlay_window` 拉起的独立 Flutter 引擎中，
/// 通过 `FlutterOverlayWindow.overlayListener` 接收主 App 发来的数据。
class OverlayHost extends StatefulWidget {
  const OverlayHost({super.key});

  @override
  State<OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<OverlayHost> {
  StreamSubscription<dynamic>? _subscription;

  String? _mode;
  String _packageName = '';
  int _snoozeMinutes = 5;

  @override
  void initState() {
    super.initState();
    _subscription = FlutterOverlayWindow.overlayListener.listen((data) {
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          _mode = data['mode'] as String? ?? _mode;
          _packageName = data['packageName'] as String? ?? _packageName;
          _snoozeMinutes = data['snoozeMinutes'] as int? ?? _snoozeMinutes;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  ReminderMode get _reminderMode =>
      ReminderMode.fromStorage(_mode ?? ReminderMode.strong.storageKey);

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
    // 尚未收到数据时展示一个很轻的占位，避免黑屏。
    if (_packageName.isEmpty) {
      return const Material(
        color: Color(0xE6202026),
        child: Center(
          child: Text(
            '够了吗',
            style: TextStyle(color: Colors.white70, fontSize: 20),
          ),
        ),
      );
    }

    final mode = _reminderMode;
    if (mode == ReminderMode.strong) {
      return StrongReminderView(
        packageName: _packageName,
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
              packageName: _packageName,
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
