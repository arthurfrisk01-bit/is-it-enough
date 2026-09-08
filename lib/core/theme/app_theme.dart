import 'package:flutter/material.dart';

/// 全局主题。
///
/// “够了吗”定位是睡前/碎片时间使用的数字健康工具，
/// 采用偏深色、低刺激的视觉，避免界面本身成为新的刷屏诱因。
class AppTheme {
  AppTheme._();

  static const Color _ink = Color(0xFF1C1B20);
  static const Color _surface = Color(0xFF26252C);
  static const Color _primary = Color(0xFF6C8CD5);
  static const Color _accent = Color(0xFF9ED8C4);

  static ThemeData get dark {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        secondary: _accent,
        surface: _surface,
      ),
      scaffoldBackgroundColor: _ink,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: _ink,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
