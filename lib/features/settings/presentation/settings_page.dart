import 'package:flutter/material.dart';
import 'package:is_it_enough/core/constants/app_constants.dart';
import 'package:is_it_enough/core/constants/monitor_list_modes.dart';
import 'package:is_it_enough/core/constants/reminder_modes.dart';
import 'package:is_it_enough/core/navigation/app_navigator.dart';
import 'package:is_it_enough/features/breathing/breathing_page.dart';
import 'package:is_it_enough/features/logs/log_export_dialog.dart';
import 'package:is_it_enough/features/logs/log_viewer_page.dart';
import 'package:is_it_enough/features/reminder/reminder_overlay_channel.dart';
import 'package:is_it_enough/features/settings/presentation/app_picker_page.dart';
import 'package:is_it_enough/features/settings/presentation/auto_start_guide_page.dart';
import 'package:is_it_enough/features/settings/presentation/install_trust_page.dart';
import 'package:is_it_enough/features/settings/presentation/update_page.dart';
import 'package:is_it_enough/shared/services/logger_service.dart';
import 'package:is_it_enough/shared/services/notification_service.dart';
import 'package:is_it_enough/shared/services/permission_diagnosis_service.dart';
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
            _buildAutoStartCard(context, settings),
            const SizedBox(height: 12),
            _buildModeCard(context, settings),
            const SizedBox(height: 12),
            _buildThresholdCard(context, settings),
            const SizedBox(height: 12),
            _buildListModeCard(context, settings),
            const SizedBox(height: 12),
            _buildScheduleCard(context, settings),
            const SizedBox(height: 12),
            _buildUpdateCard(context),
            const SizedBox(height: 12),
            _buildTrustCard(context),
            const SizedBox(height: 12),
            _buildDebugSection(context, settings),
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

  // ---------- 自启动 ----------

  /// 自启动开关 + 厂商保活引导入口。
  ///
  /// 国产 ROM 会杀后台，进程被清掉后提醒彻底失效；这里给一个显式开关和
  /// 一份「去系统设置打开哪几项」的说明页。
  Widget _buildAutoStartCard(BuildContext context, SettingsService settings) {
    return _SectionCard(
      title: '自启动与保活',
      icon: Icons.restart_alt,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('开机自启动'),
            subtitle: const Text('重启/应用更新后自动恢复后台监控服务'),
            value: settings.autoStartEnabled,
            onChanged: (value) => settings.setAutoStartEnabled(value),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('自启动引导'),
            subtitle: const Text('小米/华为/OPPO/vivo 需要手动放行的 3 项设置'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AutoStartGuidePage(),
                ),
              );
            },
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
              // 双层兜底：仓库层已校验，这里再挡一次，
              // 保证 selected 一定是 segments 里的值（否则 SegmentedButton 断言崩溃）。
              selected: {
                AppConstants.thresholdOptions.contains(settings.thresholdMinutes)
                    ? settings.thresholdMinutes
                    : AppConstants.defaultThresholdMinutes,
              },
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

  // ---------- 监控名单（模式 + 详细选单） ----------

  Widget _buildListModeCard(BuildContext context, SettingsService settings) {
    final mode = settings.monitorListMode;
    final list = settings.listPackageNames;
    return _SectionCard(
      title: '监控名单模式',
      icon: Icons.filter_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '黑名单与白名单互斥，也可以两个都不开启（默认监控所有应用）。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in MonitorListMode.values)
            _ListModeOption(
              title: item.label,
              subtitle: item.description,
              selected: mode == item,
              onTap: () => settings.setMonitorListMode(item),
            ),
          if (mode.isEnabled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openAppPicker(context, settings),
                icon: const Icon(Icons.apps, size: 18),
                label: Text(
                  list.isEmpty
                      ? '选择应用（已选 0 个）'
                      : '管理名单（已选 ${list.length} 个）',
                ),
              ),
            ),
            if (mode == MonitorListMode.whitelist && list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '白名单为空：当前不会监控任何应用，请先添加应用。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: const Color(0xFFFFB4A2).withValues(alpha: 0.95),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAppPicker(
    BuildContext context,
    SettingsService settings,
  ) async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute<Set<String>>(
        fullscreenDialog: true,
        builder: (_) => AppPickerPage(
          mode: settings.monitorListMode,
          initialSelected: settings.listPackageNames,
        ),
      ),
    );
    if (result != null) {
      await settings.updateListPackages(result);
    }
  }

  // ---------- 时段限制 ----------

  Widget _buildScheduleCard(BuildContext context, SettingsService settings) {
    final schedule = settings.schedule;
    return _SectionCard(
      title: '时段限制',
      icon: Icons.schedule_outlined,
      trailing: Switch(
        value: schedule.enabled,
        onChanged: (value) => settings.updateSchedule(
          schedule.copyWith(enabled: value),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schedule.enabled
                ? '只在 ${schedule.label} 内按上面的“提醒强度”提醒，时段外按下面的设置处理。'
                : '关闭时不限时段，全天按“提醒强度”提醒。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          if (schedule.enabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: '开始时间',
                    minutes: schedule.startMinutes,
                    onPick: (minutes) => settings.updateSchedule(
                      schedule.copyWith(startMinutes: minutes),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeField(
                    label: '结束时间',
                    minutes: schedule.endMinutes,
                    onPick: (minutes) => settings.updateSchedule(
                      schedule.copyWith(endMinutes: minutes),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '跨零点也可以，例如 22:00 开始、07:00 结束。',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '时段外提醒强度',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            for (final outside in OutsideScheduleMode.values)
              _ListModeOption(
                title: outside.label,
                subtitle: outside.description,
                selected: schedule.outsideMode == outside,
                onTap: () => settings.updateSchedule(
                  schedule.copyWith(outsideMode: outside),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ---------- 检查更新 ----------

  Widget _buildUpdateCard(BuildContext context) {
    return _SectionCard(
      title: '检查更新',
      icon: Icons.system_update_alt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD89C).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFFFD89C).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              '更新会联网，请注意隐私安全：\n'
              '检查更新会访问 GitHub 的公开接口，只发送当前版本号用于比对，'
              '不会上传使用数据、应用清单或任何个人信息。不点击时本应用完全离线。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const UpdatePage()),
              ),
              icon: const Icon(Icons.cloud_download_outlined, size: 18),
              label: const Text('打开检查更新'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 安装来源 / 受限设置 ----------

  Widget _buildTrustCard(BuildContext context) {
    return _SectionCard(
      title: '安装来源与受限设置',
      icon: Icons.verified_user_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Android 13 及以上，通过浏览器或文件管理器侧载（非应用商店）安装的应用会被系统标记为“受限”，'
            '导致“使用情况访问”“悬浮窗”等权限开关置灰、点不动。可以在这里自检安装来源并按系统要求手动解除。',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const InstallTrustPage(),
                ),
              ),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text('查看安装来源自检'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 权限引导 ----------

  Widget _buildDebugSection(BuildContext context, SettingsService settings) {
    return _SectionCard(
      title: '调试选项',
      icon: Icons.bug_report_outlined,
      child: Column(
        children: [
          if (settings.debugMode)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD89C).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFFD89C).withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                '⚠️ 调试模式开启中：提醒阈值被覆盖为 1 分钟、日志全量输出。'
                '正式使用/发版前请关闭。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.developer_mode_outlined),
            title: const Text('调试模式'),
            subtitle: const Text('提醒时间变为1分钟，日志全量输出'),
            trailing: Switch(
              value: settings.debugMode,
              onChanged: (v) => settings.setDebugMode(v),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('提醒通道自检'),
            subtitle: const Text('测试系统通知、悬浮窗、App内页三重提醒'),
            onTap: () => _runReminderChannelTest(context, settings),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('权限深度诊断'),
            subtitle: const Text('检查所有权限状态和通知通道创建情况'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _runPermissionDiagnosis(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.save_alt_outlined),
            title: const Text('导出全量日志'),
            subtitle: const Text('日志+系统状态保存到下载目录，用于排查不弹通知'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => exportAndShowLogs(context),
          ),
        ],
      ),
    );
  }

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
            subtitle: const Text('全屏提醒必需（覆盖在当前应用之上）'),
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

  /// 提醒通道自检：测试三重提醒是否正常
  Future<void> _runReminderChannelTest(BuildContext context, SettingsService settings) async {
    final logger = LoggerService();
    final messenger = ScaffoldMessenger.of(context);
    
    logger.info('=== 开始提醒通道自检 ===', tag: 'SelfTest');
    
    // 显示进度对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('测试提醒通道...'),
          ],
        ),
      ),
    );
    
    try {
      // 1. 测试系统通知
      logger.info('1/3 测试系统通知通道', tag: 'SelfTest');
      final notificationSent = await NotificationReminderService().showReminder(
        mode: settings.reminderMode,
        continuousMinutes: 999,  // 测试标记
        appLabel: '测试应用',
      );
      logger.info('系统通知测试结果: ${notificationSent ? "成功" : "失败"}', tag: 'SelfTest');
      
      // 2. 真实显示一次原生悬浮窗（2.5 秒后自动关闭），确认“前台全屏”这条路能走通
      logger.info('2/3 测试原生悬浮窗', tag: 'SelfTest');
      final overlayGranted = await ReminderOverlayChannel.isPermissionGranted();
      logger.info('悬浮窗权限: ${overlayGranted ? "已授予" : "未授予"}', tag: 'SelfTest');
      var overlayShown = false;
      if (overlayGranted) {
        overlayShown = await ReminderOverlayChannel.show(
          mode: settings.reminderMode.storageKey,
          appName: '自检',
          snoozeMinutes: 1,
          continuousMinutes: 1,
        );
        logger.info('悬浮窗显示结果: $overlayShown', tag: 'SelfTest');
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        await ReminderOverlayChannel.hide();
      }
      
      // 3. 测试App内页
      logger.info('3/3 测试App内提醒页', tag: 'SelfTest');
      final hasNavigator = appNavigatorKey.currentState != null;
      logger.info('Navigator可用: $hasNavigator', tag: 'SelfTest');
      
      logger.info('=== 自检完成 ===', tag: 'SelfTest');
      
      // 关闭进度对话框
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // 生成报告
      final report = StringBuffer();
      report.writeln('提醒通道自检报告：\n');
      report.writeln('✓ 系统通知：${notificationSent ? "✅ 正常" : "❌ 失败"}');
      report.writeln(
        '✓ 悬浮窗：${overlayShown ? "✅ 已显示" : (overlayGranted ? "❌ 显示失败（锁屏或被系统拦截）" : "❌ 未授权")}',
      );
      report.writeln('✓ App内页：${hasNavigator ? "✅ 可用" : "❌ 不可用"}');
      report.writeln('\n建议：');
      if (!notificationSent) {
        report.writeln('• 请在系统设置中授予通知权限');
      }
      if (!overlayGranted) {
        report.writeln('• 请在下方"悬浮窗权限"中授权');
      }
      if (notificationSent || overlayShown || hasNavigator) {
        report.writeln('• 至少有一个提醒通道可用，正常');
      } else {
        logger.fatal('所有提醒通道均不可用！', tag: 'SelfTest');
        report.writeln('• ⚠️ 所有通道均不可用，请检查权限');
      }
      
      // 显示结果对话框
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('自检报告'),
            content: SingleChildScrollView(
              child: Text(
                report.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // 打开日志页查看详细信息
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LogViewerPage(),
                    ),
                  );
                },
                child: const Text('查看日志'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
      
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            notificationSent || overlayShown
                ? '自检完成：至少有一个通道可用'
                : '自检完成：所有通道不可用，请检查权限',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      logger.error('自检异常: $e', tag: 'SelfTest');
      if (context.mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text('自检失败: $e')),
        );
      }
    }
  }

  /// 权限深度诊断：检查所有权限和通知通道创建状态。
  Future<void> _runPermissionDiagnosis(BuildContext context) async {
    final logger = LoggerService();
    logger.info('=== 开始权限深度诊断 ===', tag: 'PermDiag');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('正在检查所有权限和通知通道...')),
          ],
        ),
      ),
    );

    try {
      final diagService = PermissionDiagnosisService();
      final report = await diagService.diagnose();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // 关闭进度对话框

      // 显示诊断报告
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                report.allOk
                    ? Icons.check_circle_outline
                    : report.hasError
                        ? Icons.error_outline
                        : Icons.warning_amber,
                color: report.allOk
                    ? Colors.green
                    : report.hasError
                        ? Colors.red
                        : Colors.orange,
              ),
              const SizedBox(width: 8),
              const Text('权限诊断报告'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '✅ ${report.okCount} 项正常  ⚠️ ${report.warningCount} 项警告  ❌ ${report.errorCount} 项错误',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 20),
                  ...report.items.map((item) {
                    final icon = item.status == DiagnosisStatus.ok
                        ? '✅'
                        : item.status == DiagnosisStatus.warning
                            ? '⚠️'
                            : '❌';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$icon ${item.name}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.detail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          if (item.suggestion != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '💡 ${item.suggestion}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9ED8C4),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      logger.error('权限诊断失败: $e', tag: 'PermDiag');
      if (context.mounted) {
        Navigator.of(context).pop(); // 关闭进度对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('诊断失败: $e')),
        );
      }
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

/// 通用单选行（名单模式 / 时段外强度共用）。
class _ListModeOption extends StatelessWidget {
  const _ListModeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
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
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? primary : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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

/// 时间选择字段（点击弹出系统时间选择器）。
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.minutes,
    required this.onPick,
  });

  final String label;
  final int minutes;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: (minutes ~/ 60) % 24,
            minute: minutes % 60,
          ),
        );
        if (picked != null) {
          onPick(picked.hour * 60 + picked.minute);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ScheduleConfig.formatMinutes(minutes),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
