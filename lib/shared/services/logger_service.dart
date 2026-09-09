import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 日志级别。
enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal;

  int get priority {
    switch (this) {
      case LogLevel.debug:
        return 0;
      case LogLevel.info:
        return 1;
      case LogLevel.warning:
        return 2;
      case LogLevel.error:
        return 3;
      case LogLevel.fatal:
        return 4;
    }
  }
}

/// 日志条目。
class LogEntry {
  LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.tag,
    this.isolate = 'UI',
  });

  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? tag;

  /// 产生该日志的 Flutter 引擎（UI / Monitor / Overlay）。
  final String isolate;

  String get formattedTime {
    final t = timestamp;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}.'
        '${t.millisecond.toString().padLeft(3, '0')}';
  }

  String get levelText {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.fatal:
        return 'FATAL';
    }
  }

  @override
  String toString() {
    final tagPart = tag != null ? '[$tag] ' : '';
    return '[$formattedTime] $levelText: $tagPart$message';
  }
}

/// 全局日志服务。
///
/// 双通道：
/// 1. 内存队列（供日志页展示，最多 2000 条）；
/// 2. 原生日志文件（`com.isitenough.app/log` 通道）——**每条日志实时落盘**，
///    界面引擎 / 后台 headless 引擎 / Overlay 引擎写的是同一份文件，
///    因此“导出日志”能拿到跨引擎、跨进程的全量记录。
///
/// 落盘本身绝不再写日志（避免异常时无限递归）。
class LoggerService extends ChangeNotifier {
  factory LoggerService() => _instance;
  LoggerService._internal();
  static final LoggerService _instance = LoggerService._internal();

  static const MethodChannel _logChannel = MethodChannel('com.isitenough.app/log');

  final _logs = Queue<LogEntry>();
  static const _maxLogs = 2000;

  /// 当前引擎标识，启动时由各入口设置（UI / Monitor / Overlay）。
  static String isolateName = 'UI';

  /// 是否把日志写进原生文件。
  ///
  /// Overlay 隔离区的引擎由 flutter_overlay_window 插件自己创建，没有注册
  /// 我们的原生日志桥，写盘必然失败；由 overlay_main 关掉，关键日志改走
  /// shareData 回传主 App 落盘。
  static bool persistToNative = true;

  bool _persistEnabled = !kIsWeb && Platform.isAndroid;

  /// 调试模式：true 时所有级别日志都输出到 console。
  bool _debugMode = false;
  bool get debugMode => _debugMode;
  set debugMode(bool value) {
    _debugMode = value;
    notifyListeners();
  }

  /// 所有日志条目。
  List<LogEntry> get logs => _logs.toList();

  /// 获取 warning 及以上级别的日志。
  List<LogEntry> getWarningsAndAbove() {
    return _logs
        .where((e) => e.level.priority >= LogLevel.warning.priority)
        .toList();
  }

  /// 当前引擎内存日志的完整文本（导出用）。
  String fullText() => _logs.map((e) => '[$isolateName] $e').join('\n');

  void debug(String message, {String? tag}) =>
      _log(LogLevel.debug, message, tag: tag);
  void info(String message, {String? tag}) =>
      _log(LogLevel.info, message, tag: tag);
  void warning(String message, {String? tag}) =>
      _log(LogLevel.warning, message, tag: tag);
  void error(String message, {String? tag}) =>
      _log(LogLevel.error, message, tag: tag);
  void fatal(String message, {String? tag}) =>
      _log(LogLevel.fatal, message, tag: tag);

  void _log(LogLevel level, String message, {String? tag}) {
    final entry = LogEntry(
      level: level,
      message: message,
      timestamp: DateTime.now(),
      tag: tag,
      isolate: isolateName,
    );
    _logs.addLast(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
    // 调试模式：全量输出；正常模式：只输出 WARNING 及以上
    if (_debugMode || level.priority >= LogLevel.warning.priority) {
      debugPrint('[$isolateName] ${entry.toString()}');
    }
    _persist(entry);
    notifyListeners();
  }

  /// 实时写入原生日志文件（失败静默，绝不递归记日志）。
  void _persist(LogEntry entry) {
    if (!persistToNative || !_persistEnabled) return;
    try {
      unawaited(
        _logChannel
            .invokeMethod<void>('append', {'line': '[$isolateName] ${entry.toString()}'})
            .then<void>((_) {}, onError: (Object _) {}),
      );
    } catch (_) {
      // 通道不可用（例如 Overlay 引擎未注册原生通道）：放弃落盘即可。
      _persistEnabled = false;
    }
  }

  /// 清空日志：内存队列 + 原生日志文件。
  Future<void> clear() async {
    _logs.clear();
    notifyListeners();
    try {
      await _logChannel.invokeMethod<void>('clear');
    } catch (_) {
      // 忽略：无原生通道时只清内存。
    }
    info('日志已清空', tag: 'Logger');
  }

  static bool _handlersInstalled = false;

  /// 安装全局异常捕获：未捕获异常也会进入日志，随导出一起带走。
  static void installErrorHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    final logger = LoggerService();
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      logger.fatal(
        '未捕获 Flutter 异常: ${details.exception}\n${details.stack}',
        tag: 'Crash',
      );
      previousOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logger.fatal('未捕获 Dart 异常: $error\n$stack', tag: 'Crash');
      return true;
    };
  }
}
