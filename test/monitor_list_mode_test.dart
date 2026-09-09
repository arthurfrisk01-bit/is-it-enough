import 'package:flutter_test/flutter_test.dart';
import 'package:is_it_enough/core/constants/monitor_list_modes.dart';

/// 锁定监控名单语义，避免黑白名单再次写反。
///
/// 约定（与设置页文案一致）：
/// - 黑名单：只监控名单里的应用（名单外不监控）；
/// - 白名单：名单里的应用不监控（其余照常监控）；
/// - 不启用：监控所有应用。
void main() {
  const inList = 'com.tencent.mm';
  const outList = 'com.example.other';
  const list = <String>{inList};

  group('MonitorListMode.shouldIgnorePackage', () {
    test('不启用：两个应用都不跳过', () {
      expect(MonitorListMode.off.shouldIgnorePackage(inList, list), isFalse);
      expect(MonitorListMode.off.shouldIgnorePackage(outList, list), isFalse);
    });

    test('黑名单：名单内被监控，名单外不监控', () {
      expect(
        MonitorListMode.blacklist.shouldIgnorePackage(inList, list),
        isFalse,
        reason: '黑名单里的应用应当被监控',
      );
      expect(
        MonitorListMode.blacklist.shouldIgnorePackage(outList, list),
        isTrue,
        reason: '黑名单外的应用不监控',
      );
    });

    test('白名单：名单内不监控，名单外被监控', () {
      expect(
        MonitorListMode.whitelist.shouldIgnorePackage(inList, list),
        isTrue,
        reason: '白名单里的应用不监控',
      );
      expect(
        MonitorListMode.whitelist.shouldIgnorePackage(outList, list),
        isFalse,
        reason: '白名单外的应用照常监控',
      );
    });

    test('空名单：黑名单什么都不监控，白名单照常监控', () {
      expect(MonitorListMode.blacklist.shouldIgnorePackage(inList, const {}), isTrue);
      expect(MonitorListMode.whitelist.shouldIgnorePackage(inList, const {}), isFalse);
    });
  });

  group('MonitorListMode 文案与存储', () {
    test('标签与说明对应正确', () {
      expect(MonitorListMode.blacklist.label, '黑名单');
      expect(MonitorListMode.blacklist.description, '只监控名单里的应用');
      expect(MonitorListMode.whitelist.label, '白名单');
      expect(MonitorListMode.whitelist.description, '名单里的应用不监控');
      expect(MonitorListMode.off.description, '监控所有应用（默认）');
    });

    test('存储键解析', () {
      expect(MonitorListMode.fromStorage('blacklist'), MonitorListMode.blacklist);
      expect(MonitorListMode.fromStorage('whitelist'), MonitorListMode.whitelist);
      expect(MonitorListMode.fromStorage('off'), MonitorListMode.off);
      expect(MonitorListMode.fromStorage(null), MonitorListMode.off);
      expect(MonitorListMode.fromStorage('乱码'), MonitorListMode.off);
    });

    test('互斥：isEnabled 只在非 off 时为真', () {
      expect(MonitorListMode.off.isEnabled, isFalse);
      expect(MonitorListMode.blacklist.isEnabled, isTrue);
      expect(MonitorListMode.whitelist.isEnabled, isTrue);
    });
  });
}
