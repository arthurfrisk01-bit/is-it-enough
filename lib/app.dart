import 'package:flutter/material.dart';
import 'package:is_it_enough/core/navigation/app_navigator.dart';
import 'package:is_it_enough/core/theme/app_theme.dart';
import 'package:is_it_enough/features/settings/presentation/settings_page.dart';

/// 应用根组件。
class IsItEnoughApp extends StatelessWidget {
  const IsItEnoughApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '够了吗',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.dark,
      home: const SettingsPage(),
    );
  }
}
