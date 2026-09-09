import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 一次更新检查的结果。
class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.notes,
    required this.releaseUrl,
    required this.downloadUrl,
    this.publishedAt,
  });

  final String currentVersion;
  final String latestVersion;
  final String notes;
  final String releaseUrl;

  /// APK 直链；Release 没有 APK 附件时为空。
  final String downloadUrl;

  final DateTime? publishedAt;

  bool get hasUpdate =>
      UpdateService.compareVersions(latestVersion, currentVersion) > 0;
}

/// 检查更新结果：成功带 [info]，失败带 [error]。
class UpdateCheckResult {
  const UpdateCheckResult({this.info, this.error});

  final UpdateInfo? info;
  final String? error;

  bool get ok => info != null;
}

/// 检查更新。
///
/// 隐私说明（UI 必须同步展示）：这是本应用唯一的联网功能，
/// 只访问 GitHub 的公开 Release 接口，仅发送当前版本号用于比对；
/// 不会上传使用数据、应用清单或任何个人信息。不点“检查更新”就完全离线。
class UpdateService {
  UpdateService._();

  static const String repoOwner = 'arthurfrisk01-bit';
  static const String repoName = 'is-it-enough';
  static const String releasesPageUrl =
      'https://github.com/$repoOwner/$repoName/releases';

  static const String _latestApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static Future<UpdateCheckResult> check({required String currentVersion}) async {
    // 读不到本机版本号时不能瞎比：'—' 会被当成 0.0.0，误报“有新版本”。
    if (!RegExp(r'\d').hasMatch(currentVersion)) {
      return const UpdateCheckResult(error: '无法读取当前版本号，请稍后重试。');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(_latestApiUrl));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'is-it-enough/$currentVersion');
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        return UpdateCheckResult(
          error: '无法获取版本信息（HTTP ${response.statusCode}）。请检查网络后重试。',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return const UpdateCheckResult(error: '版本信息格式异常，请稍后重试。');
      }
      final tag = (decoded['tag_name'] as String? ?? '').trim();
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latest.isEmpty) {
        return const UpdateCheckResult(error: '版本信息里没有版本号。');
      }
      final assets = (decoded['assets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((a) => a['browser_download_url'] as String? ?? '')
          .where((url) => url.toLowerCase().endsWith('.apk'))
          .toList();
      return UpdateCheckResult(
        info: UpdateInfo(
          currentVersion: currentVersion,
          latestVersion: latest,
          notes: (decoded['body'] as String? ?? '').trim(),
          releaseUrl: decoded['html_url'] as String? ?? releasesPageUrl,
          downloadUrl: assets.isEmpty ? '' : assets.first,
          publishedAt: DateTime.tryParse(decoded['published_at'] as String? ?? ''),
        ),
      );
    } on TimeoutException {
      return const UpdateCheckResult(error: '网络超时，请检查网络后重试。');
    } on SocketException {
      return const UpdateCheckResult(error: '无法连接网络，请检查网络后重试。');
    } on FormatException {
      return const UpdateCheckResult(error: '版本信息解析失败，请稍后重试。');
    } catch (e) {
      return UpdateCheckResult(error: '检查更新失败：$e');
    } finally {
      client.close(force: true);
    }
  }

  /// 语义化版本比较：a > b 返回正数，相等返回 0，小于返回负数。
  static int compareVersions(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final length = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < length; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  static List<int> _parts(String version) {
    return version
        .split(RegExp(r'[.+-]'))
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }
}
