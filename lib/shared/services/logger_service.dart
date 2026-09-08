import 'dart:collection';

import 'package:flutter/foundation.dart';

/// 日志级别。
enum LogLevel {
  debug,
  info,
  warning,
  error;

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
  });

  final LogLevel level;
  final String message;
  final DateTime timestamp;
  final String? tag;

  String get formattedTime {
    final t = timestamp;
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:'
        '${t.second.toString().padLeft(2, '0')}';
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
    }
  }

  @override
  String toString() {
    final tagPart = tag != null ? '[$tag] ' : '';
    return '[$formattedTime] $levelText: $tagPart$message';
  }
}

/// 全局日志服务，内存队列，最多保留 500 条。
class LoggerService extends ChangeNotifier {
  factory LoggerService() => _instance;
  LoggerService._internal();
  static final LoggerService _instance = LoggerService._internal();

  final _logs = Queue<LogEntry>();
  static const _maxLogs = 500;

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

  void debug(String message, {String? tag}) =>
      _log(LogLevel.debug, message, tag: tag);
  void info(String message, {String? tag}) =>
      _log(LogLevel.info, message, tag: tag);
  void warning(String message, {String? tag}) =>
      _log(LogLevel.warning, message, tag: tag);
  void error(String message, {String? tag}) =>
      _log(LogLevel.error, message, tag: tag);

  void _log(LogLevel level, String message, {String? tag}) {
    final entry = LogEntry(
      level: level,
      message: message,
      timestamp: DateTime.now(),
      tag: tag,
    );
    _logs.addLast(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeFirst();
    }
    // 调试模式：全量输出；正常模式：只输出 WARNING 及以上
    if (_debugMode || level.priority >= LogLevel.warning.priority) {
      debugPrint(entry.toString());
    }
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
