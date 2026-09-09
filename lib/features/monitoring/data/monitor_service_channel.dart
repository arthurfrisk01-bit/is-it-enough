import 'package:flutter/services.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';

/// 与原生“后台监控保活服务”通信的通道。
///
/// 该服务承担两件事：
/// 1. 常驻前台通知，把进程优先级提升为 foreground，降低被 ROM 回收的概率；
/// 2. App 界面不存在时（开机自启 / 进程被系统回收后）拉起无界面 Flutter
///    引擎执行 [monitorMain]，让监控继续工作。
class MonitorServiceChannel {
  const MonitorServiceChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.isitenough.app/monitor_service');

  /// 启动保活服务（幂等，重复调用不会重复创建服务）。
  static Future<void> start() async {
    try {
      await _channel.invokeMethod<bool>('start');
    } catch (e) {
      LoggerService().warning('启动后台监控服务失败: $e', tag: 'MonitorService');
    }
  }

  /// 停止保活服务（用户关闭后台监控时调用）。
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (e) {
      LoggerService().debug('停止后台监控服务失败: $e', tag: 'MonitorService');
    }
  }
}
