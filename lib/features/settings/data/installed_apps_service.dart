import 'dart:convert';

import 'package:flutter/services.dart';

/// 本机已安装、带桌面图标的应用。
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    required this.isSystem,
  });

  final String packageName;
  final String label;

  /// 是否为系统应用（系统应用一般不需要加入名单）。
  final bool isSystem;

  factory InstalledApp.fromJson(Map<String, dynamic> json) {
    return InstalledApp(
      packageName: json['packageName'] as String? ?? '',
      label: json['label'] as String? ?? '',
      isSystem: json['isSystem'] as bool? ?? false,
    );
  }
}

/// 本应用自身的安装来源 / 版本自检信息。
class SelfInstallInfo {
  const SelfInstallInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.targetSdk,
    required this.installerPackage,
    required this.isSystem,
    required this.isDebuggable,
    required this.sdkInt,
  });

  final String packageName;
  final String versionName;
  final int versionCode;
  final int targetSdk;

  /// 安装来源包名；空字符串表示“未知来源”（浏览器/文件管理器/adb）。
  final String installerPackage;

  final bool isSystem;
  final bool isDebuggable;
  final int sdkInt;

  /// 已知可信的应用商店 / 系统安装器。
  static const Set<String> trustedInstallers = <String>{
    'com.android.vending', // Google Play
    'com.google.android.packageinstaller',
    'com.android.packageinstaller',
    'com.samsung.android.packageinstaller',
    'com.miui.packageinstaller',
    'com.huawei.appmarket',
    'com.heytap.market',
    'com.oppo.market',
    'com.bbk.appstore',
  };

  bool get isTrustedSource => trustedInstallers.contains(installerPackage);

  String get installerLabel {
    if (installerPackage.isEmpty) return '未知来源（浏览器 / 文件管理器 / 数据线安装）';
    if (isTrustedSource) return '应用商店（$installerPackage）';
    return installerPackage;
  }

  /// 是否可能被系统当作“低授信应用”，从而置灰敏感权限开关。
  ///
  /// Android 13(API 33) 起，非商店渠道安装的应用默认处于受限设置状态，
  /// 需要用户手动在应用详情页解除。
  bool get needsRestrictedSettingsUnlock => sdkInt >= 33 && !isTrustedSource;

  static SelfInstallInfo? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return SelfInstallInfo(
        packageName: decoded['packageName'] as String? ?? '',
        versionName: decoded['versionName'] as String? ?? '',
        versionCode: (decoded['versionCode'] as num?)?.toInt() ?? 0,
        targetSdk: (decoded['targetSdk'] as num?)?.toInt() ?? 0,
        installerPackage: decoded['installerPackage'] as String? ?? '',
        isSystem: decoded['isSystem'] as bool? ?? false,
        isDebuggable: decoded['isDebuggable'] as bool? ?? false,
        sdkInt: (decoded['sdkInt'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// 通过原生 [InstalledAppsBridge] 读取应用清单与安装来源。
///
/// 隐私：只读取包名、应用名、是否系统应用、安装来源，全部留在本机。
class InstalledAppsService {
  InstalledAppsService._();

  static const MethodChannel _channel =
      MethodChannel('com.isitenough.app/installed_apps');

  static List<InstalledApp>? _cache;

  /// 已装应用列表（带桌面图标），按应用名排序。
  static Future<List<InstalledApp>> listApps({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final raw = await _channel.invokeMethod<String>('listLaunchableApps');
      final decoded = raw == null || raw.isEmpty ? const <dynamic>[] : jsonDecode(raw);
      if (decoded is! List) return const <InstalledApp>[];
      final apps = decoded
          .whereType<Map<String, dynamic>>()
          .map(InstalledApp.fromJson)
          .where((app) => app.packageName.isNotEmpty)
          .toList();
      _cache = apps;
      return apps;
    } on MissingPluginException {
      return const <InstalledApp>[];
    } on PlatformException {
      return const <InstalledApp>[];
    }
  }

  /// 本应用安装来源自检。
  static Future<SelfInstallInfo?> getSelfInstallInfo() async {
    try {
      final raw = await _channel.invokeMethod<String>('getSelfInstallInfo');
      return SelfInstallInfo.fromJsonString(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
