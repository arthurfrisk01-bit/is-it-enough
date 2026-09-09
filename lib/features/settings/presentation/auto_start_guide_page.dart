import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:is_it_enough/shared/services/permission_service.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:provider/provider.dart';

/// 自启动与后台保活引导页。
///
/// 国产 ROM（MIUI / EMUI / ColorOS / OriginOS）默认会清理后台进程，一旦进程被
/// 清掉，“刷太久提醒”就彻底失效。这里把需要用户手动打开的开关集中讲清楚，
/// 并提供一键跳转厂商自启动设置页的入口。
class AutoStartGuidePage extends StatelessWidget {
  const AutoStartGuidePage({super.key});

  static const String _packageName = 'com.isitenough.app';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自启动与后台保活')),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: Color(0xFF9ED8C4)),
                        SizedBox(width: 8),
                        Text(
                          '为什么必须开自启动',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '“够了吗”靠一个后台服务持续读取前台应用。国产系统默认会杀后台，'
                      '进程一旦被清理，提醒就不会再出现。把下面三项打开，监控才能长期存活。',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.restart_alt),
                      title: const Text('开机自启动'),
                      subtitle: const Text('重启或应用更新后自动恢复后台监控'),
                      value: settings.autoStartEnabled,
                      onChanged: (value) => settings.setAutoStartEnabled(value),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.monitor_heart_outlined),
                      title: const Text('后台监控'),
                      subtitle: Text(
                        settings.monitoringEnabled
                            ? '已开启（常驻通知栏显示当前使用时长）'
                            : '已关闭，不会触发提醒',
                      ),
                      trailing: Switch(
                        value: settings.monitoringEnabled,
                        onChanged: (value) =>
                            settings.setMonitoringEnabled(value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '需要在系统设置里打开的 3 项',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _StepRow(
                      index: 1,
                      title: '自启动 / 开机启动',
                      desc: '允许应用在开机后自动运行',
                    ),
                    const SizedBox(height: 10),
                    const _StepRow(
                      index: 2,
                      title: '后台运行 / 关联启动',
                      desc: '不要把应用从后台清掉',
                    ),
                    const SizedBox(height: 10),
                    const _StepRow(
                      index: 3,
                      title: '省电策略 → 无限制',
                      desc: '关闭“智能省电/深度睡眠”对应用的限制',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF9ED8C4),
                          foregroundColor: const Color(0xFF101010),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _openAutoStartSettings(context),
                        icon: const Icon(Icons.settings_suggest_outlined),
                        label: const Text('前往系统自启动设置'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openAppDetails(context),
                        icon: const Icon(Icons.app_settings_alt_outlined, size: 18),
                        label: const Text('打开应用详情页（省电/权限）'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notifications_none,
                        size: 20, color: Colors.white54),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '通知栏里那条“够了吗”常驻通知是后台守护的证明，它会显示你当前'
                        '正在用的应用和已用时长，属于正常现象。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAutoStartSettings(BuildContext context) async {
    try {
      await PermissionService().openAutoStartSettings();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开失败：$e')),
      );
    }
  }

  Future<void> _openAppDetails(BuildContext context) async {
    try {
      const intent = AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$_packageName',
      );
      await intent.launch();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开失败：$e')),
      );
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: child,
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.title,
    required this.desc,
  });

  final int index;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0x269ED8C4),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF9ED8C4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
