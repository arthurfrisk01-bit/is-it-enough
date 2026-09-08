import 'package:flutter/material.dart';
import 'package:is_it_enough/shared/services/permission_service.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';
import 'package:provider/provider.dart';

/// 初次启动引导页：检查关键权限、演示强弱模式。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  bool _usageOk = false;
  bool _overlayOk = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final perm = PermissionService();
    final usage = await perm.hasUsageAccess();
    final overlay = await perm.hasOverlayPermission();
    setState(() {
      _usageOk = usage;
      _overlayOk = overlay;
    });
    final logger = LoggerService();
    logger.info('引导页权限检查: UsageStats=$usage, Overlay=$overlay', tag: 'Onboarding');
  }

  @override
  Widget build(BuildContext context) {
    if (_step == 0) {
      return _buildWelcome();
    } else if (_step == 1) {
      return _buildPermissionCheck();
    } else {
      return _buildModeDemo();
    }
  }

  Widget _buildWelcome() {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.self_improvement_outlined,
              size: 80,
              color: Color(0xFF9ED8C4),
            ),
            const SizedBox(height: 32),
            const Text(
              '够了吗',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '在你无意识刷手机时，温和地问一句：\n够了吗？',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('开始设置'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCheck() {
    final allGood = _usageOk && _overlayOk;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _step = 0),
        ),
        title: const Text('权限检查'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _PermissionTile(
                    icon: Icons.access_time_outlined,
                    title: '使用情况访问',
                    desc: 'Android UsageStatsManager 监听前台应用',
                    granted: _usageOk,
                    onRequest: () async {
                      await PermissionService().requestUsageAccess();
                      await _checkPermissions();
                    },
                  ),
                  const SizedBox(height: 12),
                  _PermissionTile(
                    icon: Icons.picture_in_picture_alt_outlined,
                    title: '悬浮窗权限',
                    desc: '显示打断提醒',
                    granted: _overlayOk,
                    onRequest: () async {
                      await PermissionService().requestOverlayPermission();
                      await _checkPermissions();
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '提示：部分厂商（华为/小米/OPPO/vivo）还需手动开启后台自启与省电白名单，可在设置页稍后配置。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: allGood ? () => setState(() => _step = 2) : null,
                child: Text(allGood ? '继续' : '请先授予权限'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeDemo() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _step = 1),
        ),
        title: const Text('选择提醒模式'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Consumer<SettingsService>(
                builder: (context, settings, _) {
                  return ListView(
                    children: [
                      const Text(
                        '两种模式：',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      _ModeDemoCard(
                        icon: Icons.notifications_outlined,
                        title: '弱提醒',
                        desc: '小气泡悬浮窗，温和询问"够了吗"',
                        testLabel: '测试弱提醒',
                        onTest: () => _testWeakMode(context),
                      ),
                      const SizedBox(height: 12),
                      _ModeDemoCard(
                        icon: Icons.fullscreen_outlined,
                        title: '强提醒',
                        desc: '全屏悬浮窗，必须明确选择才能继续',
                        testLabel: '测试强提醒',
                        onTest: () => _testStrongMode(context),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '稍后可随时在设置中更改模式与触发阈值。',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onComplete,
                child: const Text('完成'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _testWeakMode(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(
        content: Text('弱提醒模拟：一个小气泡悬浮窗会短暂显示"够了吗"'),
      ),
    );
  }

  void _testStrongMode(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('强提醒模拟'),
        content: const Text('全屏悬浮窗会覆盖当前界面，必须选择"现在放下"或"再刷一会"才能关闭。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.desc,
    required this.granted,
    required this.onRequest,
  });

  final IconData icon;
  final String title;
  final String desc;
  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
              color: granted ? const Color(0xFF9ED8C4) : Colors.white54,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (granted)
              const Icon(Icons.check_circle, color: Color(0xFF9ED8C4))
            else
              TextButton(
                onPressed: onRequest,
                child: const Text('授权'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeDemoCard extends StatelessWidget {
  const _ModeDemoCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.testLabel,
    required this.onTest,
  });

  final IconData icon;
  final String title;
  final String desc;
  final String testLabel;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: const Color(0xFF9ED8C4)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onTest,
                child: Text(testLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
