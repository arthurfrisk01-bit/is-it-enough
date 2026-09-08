import 'package:flutter/material.dart';
import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/features/breathing/breathing_page.dart';
import 'package:is_it_enough/shared/services/permission_service.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:provider/provider.dart';

/// 设置页。
///
/// MVP 聚焦：
/// 1. Android 后台监控总开关；
/// 2. 提醒强度：弱提醒 / 强提醒；
/// 3. 触发阈值；
/// 4. 监控名单维护；
/// 5. 厂商权限跳转入口。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _buildIntro(),
            const SizedBox(height: 12),
            _buildQuickStartCard(context),
            const SizedBox(height: 12),
            _buildMonitoringCard(context, settings),
            const SizedBox(height: 12),
            _buildModeCard(context, settings),
            const SizedBox(height: 12),
            _buildThresholdCard(context, settings),
            const SizedBox(height: 12),
            _buildBlacklistCard(context, settings),
            const SizedBox(height: 12),
            _buildPermissionCard(context),
          ],
        );
      },
    );
  }

  Widget _buildIntro() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        '在你无意识刷手机时，温和地问一句：够了吗？',
        style: TextStyle(fontSize: 15, color: Colors.white60),
      ),
    );
  }

  // ---------- 主动开始（iOS 极简模式 / 用户手动入口） ----------

  Widget _buildQuickStartCard(BuildContext context) {
    return _SectionCard(
      title: '现在放下',
      icon: Icons.self_improvement_outlined,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '不依赖后台监听，现在主动开启 5 分钟呼吸专注',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9ED8C4),
                  foregroundColor: const Color(0xFF101010),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => const BreathingPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('开始专注'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 监控总开关 ----------

  Widget _buildMonitoringCard(
    BuildContext context,
    SettingsService settings,
  ) {
    return _SectionCard(
      title: '后台监控',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用 Android 使用情况监听'),
            subtitle: const Text('每 5 秒检测一次前台应用，仅在本地计算'),
            value: settings.monitoringEnabled,
            onChanged: (value) => settings.setMonitoringEnabled(value),
          ),
          const Divider(height: 1),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用智能消抖'),
            subtitle: const Text('30秒内切回原应用继续计算提醒时间'),
            value: settings.debounceEnabled,
            onChanged: (value) => settings.setDebounceEnabled(value),
          ),
        ],
      ),
    );
  }

  // ---------- 提醒强度 ----------

  Widget _buildModeCard(BuildContext context, SettingsService settings) {
    return _SectionCard(
      title: '提醒强度',
      icon: Icons.notifications_active_outlined,
      child: Column(
        children: [
          for (final mode in ReminderMode.values)
            _ModeOption(
              mode: mode,
              selected: settings.reminderMode == mode,
              onTap: () => settings.setReminderMode(mode),
            ),
        ],
      ),
    );
  }

  // ---------- 触发阈值 ----------

  Widget _buildThresholdCard(
    BuildContext context,
    SettingsService settings,
  ) {
    return _SectionCard(
      title: '触发阈值',
      icon: Icons.timer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '同一应用连续使用达到该时长后提醒',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                for (final minutes in AppConstants.thresholdOptions)
                  ButtonSegment(
                    value: minutes,
                    label: Text('$minutes 分钟'),
                  ),
              ],
              selected: {settings.thresholdMinutes},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                settings.setThresholdMinutes(selection.first);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 监控名单 ----------

  Widget _buildBlacklistCard(
    BuildContext context,
    SettingsService settings,
  ) {
    return _SectionCard(
      title: '监控名单',
      icon: Icons.apps_outlined,
      trailing: IconButton(
        tooltip: '添加包名',
        onPressed: () => _showAddPackageDialog(context, settings),
        icon: const Icon(Icons.add),
      ),
      child: settings.blacklistedPackageNames.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '暂未设置名单。\nMVP 先支持“黑名单”：添加后这些 App 不触发提醒。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            )
          : Column(
              children: [
                for (final package in settings.blacklistedPackageNames.toList()..sort())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.visibility_off_outlined, size: 20),
                    title: Text(
                      package,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    trailing: IconButton(
                      tooltip: '移除',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        final next = {...settings.blacklistedPackageNames}
                          ..remove(package);
                        settings.updateBlacklist(next);
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _showAddPackageDialog(
    BuildContext context,
    SettingsService settings,
  ) async {
    final controller = TextEditingController();
    final packageName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加不监控的包名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '包名',
            hintText: '例如 com.tencent.mm',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (packageName != null && packageName.isNotEmpty) {
      final next = {...settings.blacklistedPackageNames, packageName};
      await settings.updateBlacklist(next);
    }
  }

  // ---------- 权限引导 ----------

  Widget _buildPermissionCard(BuildContext context) {
    final permissions = PermissionService();
    return _SectionCard(
      title: '权限与兼容',
      icon: Icons.shield_outlined,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time_outlined),
            title: const Text('使用情况访问权限'),
            subtitle: const Text('Android UsageStatsManager 必需'),
            onTap: () => _launchPermission(
              context,
              () => permissions.requestUsageAccess(),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_in_picture_alt_outlined),
            title: const Text('悬浮窗权限'),
            subtitle: const Text('Overlay 强/弱提醒必需'),
            onTap: () => _launchPermission(
              context,
              () => permissions.requestOverlayPermission(),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.power_settings_new_outlined),
            title: const Text('后台自启 / 省电白名单'),
            subtitle: const Text('华为、小米、OPPO、vivo 等厂商适配'),
            onTap: () => _launchPermission(
              context,
              () => permissions.openAutoStartSettings(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPermission(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开失败：$e')),
      );
    }
  }
}

/// 卡片式分区容器。
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

/// 提醒模式单选卡片。
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ReminderMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary : Colors.white.withValues(alpha: 0.10),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? primary : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
