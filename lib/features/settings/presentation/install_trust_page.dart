import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:is_it_enough/features/settings/data/installed_apps_service.dart';

/// 安装来源 / 受限设置自检页。
///
/// Android 13(API 33) 起，非应用商店渠道安装的应用默认处于“受限设置”状态：
/// 系统会置灰「使用情况访问」「悬浮窗」等敏感权限开关，用户点了也没反应。
/// 本页读取安装来源给出判断，并引导用户到应用详情页手动解除限制。
class InstallTrustPage extends StatefulWidget {
  const InstallTrustPage({super.key});

  @override
  State<InstallTrustPage> createState() => _InstallTrustPageState();
}

class _InstallTrustPageState extends State<InstallTrustPage> {
  SelfInstallInfo? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await InstalledAppsService.getSelfInstallInfo();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  Future<void> _openAppDetails() async {
    final package = _info?.packageName ?? 'com.isitenough.app';
    try {
      await AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$package',
      ).launch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开应用详情页，请手动进入系统设置 → 应用管理。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('安装来源自检')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _buildVerdict(),
                const SizedBox(height: 20),
                if (_info != null) _buildDetails(_info!),
                const SizedBox(height: 24),
                const Text(
                  '如何解除“受限设置”',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _buildSteps(),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _openAppDetails,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('打开应用详情页'),
                ),
                const SizedBox(height: 12),
                Text(
                  '说明：本应用不会修改系统设置，也无法绕过系统限制，'
                  '“允许受限设置”只能由你本人在系统界面手动确认。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVerdict() {
    final info = _info;
    if (info == null) {
      return const _Card(
        color: Color(0xFFFFB4A2),
        icon: Icons.error_outline,
        title: '读取安装来源失败',
        body: '可能是系统限制或原生通道不可用，你仍然可以按下面的步骤手动检查。',
      );
    }
    if (info.needsRestrictedSettingsUnlock) {
      return _Card(
        color: const Color(0xFFFFB4A2),
        icon: Icons.warning_amber_rounded,
        title: '可能处于“受限设置”状态',
        body: '安装来源：${info.installerLabel}\n'
            'Android 13+ 会限制非商店渠道安装的应用，敏感权限开关可能被置灰。'
            '请按下面的步骤手动允许后再授权。',
      );
    }
    if (info.isTrustedSource) {
      return _Card(
        color: const Color(0xFF9ED8C4),
        icon: Icons.verified_outlined,
        title: '安装来源可信',
        body: '安装来源：${info.installerLabel}\n'
            '系统不会把本应用判定为受限应用，可以直接在权限页授权。',
      );
    }
    return _Card(
      color: const Color(0xFFFFD89C),
      icon: Icons.info_outline,
      title: '未识别的安装来源',
      body: '安装来源：${info.installerLabel}\n'
          '若权限开关点不动，请按下面的步骤解除“受限设置”。',
    );
  }

  Widget _buildDetails(SelfInstallInfo info) {
    final rows = <(String, String)>[
      ('包名', info.packageName),
      ('版本', '${info.versionName} (${info.versionCode})'),
      ('targetSdk', '${info.targetSdk}'),
      ('系统版本', 'Android SDK ${info.sdkInt}'),
      ('安装来源', info.installerLabel),
      ('系统应用', info.isSystem ? '是' : '否'),
      ('可调试', info.isDebuggable ? '是' : '否'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 76,
                    child: Text(
                      row.$1,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    const steps = <String>[
      '点下面的“打开应用详情页”，进入本应用的系统设置页。',
      '点右上角菜单（或“更多”），选择“允许受限设置”；'
          '部分系统在“权限”页顶部会直接出现该开关。',
      '返回本应用设置页，重新打开“使用情况访问”和“悬浮窗”权限。',
      '若仍然点不动，可以卸载后改用应用商店渠道安装，或重新侧载并在安装提示中允许该来源。',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9ED8C4).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9ED8C4)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
