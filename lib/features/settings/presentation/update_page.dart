import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:is_it_enough/features/settings/data/installed_apps_service.dart';
import 'package:is_it_enough/features/settings/data/update_service.dart';

/// 检查更新页。
///
/// 隐私：这是本应用唯一的联网功能，只在用户点击时访问 GitHub 公开接口。
class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  String _currentVersion = '—';
  bool _checking = false;
  UpdateCheckResult? _result;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
  }

  Future<void> _loadCurrentVersion() async {
    final info = await InstalledAppsService.getSelfInstallInfo();
    if (!mounted) return;
    setState(() => _currentVersion = info?.versionName ?? '—');
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    final result = await UpdateService.check(currentVersion: _currentVersion);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
    });
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await AndroidIntent(action: 'action_view', data: url).launch();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开链接：$url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('检查更新')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _PrivacyNotice(),
          const SizedBox(height: 16),
          Text(
            '当前版本：$_currentVersion',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _checking ? null : _check,
            icon: _checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_checking ? '正在检查…' : '检查更新'),
          ),
          const SizedBox(height: 20),
          if (_result != null) _buildResult(context, _result!),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, UpdateCheckResult result) {
    if (!result.ok) {
      return _InfoCard(
        icon: Icons.error_outline,
        color: const Color(0xFFFFB4A2),
        title: '检查失败',
        body: result.error ?? '未知错误',
      );
    }
    final info = result.info!;
    if (!info.hasUpdate) {
      return _InfoCard(
        icon: Icons.check_circle_outline,
        color: const Color(0xFF9ED8C4),
        title: '已是最新版本',
        body: '当前 ${info.currentVersion}，最新 ${info.latestVersion}。',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoCard(
          icon: Icons.system_update_alt,
          color: const Color(0xFF9ED8C4),
          title: '发现新版本 ${info.latestVersion}',
          body: '当前 ${info.currentVersion}'
              '${info.publishedAt == null ? '' : ' · ${info.publishedAt!.toLocal().toString().split(' ').first} 发布'}',
        ),
        const SizedBox(height: 16),
        if (info.downloadUrl.isNotEmpty)
          FilledButton.icon(
            onPressed: () => _openUrl(info.downloadUrl),
            icon: const Icon(Icons.download),
            label: const Text('下载新版本 APK'),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openUrl(info.releaseUrl),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('打开发布页查看说明'),
        ),
        if (info.notes.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            '更新说明',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              info.notes,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD89C).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD89C).withValues(alpha: 0.4)),
      ),
      child: Text(
        '更新会联网，请注意隐私安全：\n'
        '点击“检查更新”后，应用会访问 GitHub 的公开接口（api.github.com），'
        '只发送当前版本号用于比对，不会上传使用数据、应用清单或任何个人信息。'
        '不点击时本应用完全离线。',
        style: TextStyle(
          fontSize: 12,
          height: 1.6,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
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
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
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
