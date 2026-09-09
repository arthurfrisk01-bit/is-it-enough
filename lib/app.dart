import 'package:flutter/material.dart';
import 'package:is_it_enough/core/navigation/app_navigator.dart';
import 'package:is_it_enough/core/theme/app_theme.dart';
import 'package:is_it_enough/features/onboarding/onboarding_page.dart';
import 'package:is_it_enough/features/statistics/statistics_page.dart';
import 'package:is_it_enough/features/settings/presentation/settings_page.dart';
import 'package:is_it_enough/features/logs/log_viewer_page.dart';
import 'package:is_it_enough/features/reminder/app_launch_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用根组件。
class IsItEnoughApp extends StatefulWidget {
  const IsItEnoughApp({super.key});

  @override
  State<IsItEnoughApp> createState() => _IsItEnoughAppState();
}

class _IsItEnoughAppState extends State<IsItEnoughApp> {
  bool _isFirstRun = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // 界面引擎就绪：接管原生“现在放下 → 拉起 App 并打开呼吸页”的回传。
    AppLaunchChannel.init();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final firstRun = prefs.getBool('first_run') ?? true;
    setState(() {
      _isFirstRun = firstRun;
      _loading = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_run', false);
    setState(() {
      _isFirstRun = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '够了吗',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.dark,
      home: _loading
          ? const _LoadingScreen()
          : _isFirstRun
              ? OnboardingPage(onComplete: _completeOnboarding)
              : const MainTabsPage(),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 主应用 Tabs：统计首屏、设置、日志。
class MainTabsPage extends StatefulWidget {
  const MainTabsPage({super.key});

  @override
  State<MainTabsPage> createState() => _MainTabsPageState();
}

class _MainTabsPageState extends State<MainTabsPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: _currentIndex == 0
            ? [
                IconButton(
                  icon: const Icon(Icons.article_outlined),
                  tooltip: '日志',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LogViewerPage(),
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          StatisticsPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  static const _titles = ['统计', '设置'];
}
