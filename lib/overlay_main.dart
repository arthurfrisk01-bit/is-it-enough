import 'package:flutter/material.dart';
import 'package:is_it_enough/features/reminder/overlay_host.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';

/// flutter_overlay_window 的独立 Overlay 入口。
///
/// AndroidManifest 中需把插件自带的 OverlayService 指向该入口，
/// 具体服务名/Activity 名以 `flutter_overlay_window` 插件 README 为准。
@pragma('vm:entry-point')
Future<void> overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  LoggerService.isolateName = 'Overlay';
  // Overlay 引擎由插件自己创建，没有注册我们的原生日志桥，写盘必然失败；
  // 关掉落盘，关键事件由 OverlayHost 用 shareData 回传主 App 落盘。
  LoggerService.persistToNative = false;
  LoggerService.installErrorHandlers();
  runApp(const OverlayHostApp());
}

class OverlayHostApp extends StatelessWidget {
  const OverlayHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayHost(),
    );
  }
}
