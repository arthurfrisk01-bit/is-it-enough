import 'package:flutter_test/flutter_test.dart';
import 'package:is_it_enough/app.dart';
import 'package:is_it_enough/features/settings/data/repositories/settings_repository.dart';
import 'package:is_it_enough/features/settings/data/repositories/statistics_repository.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:is_it_enough/shared/services/statistics_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('主界面渲染统计页，切到设置页可见监控开关', (WidgetTester tester) async {
    // first_run=false 跳过引导页，直接进主界面。
    SharedPreferences.setMockInitialValues({'first_run': false});

    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(SettingsRepository(prefs));
    await settingsService.load();
    final statisticsService = StatisticsService(StatisticsRepository(prefs));
    await statisticsService.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(value: settingsService),
          ChangeNotifierProvider<StatisticsService>.value(
            value: statisticsService,
          ),
        ],
        child: const IsItEnoughApp(),
      ),
    );

    // 首帧还在 _LoadingScreen（异步读取 first_run），必须等它结束。
    await tester.pumpAndSettle();

    // 统计页（默认 tab）
    expect(find.text('统计'), findsWidgets);
    expect(find.text('现在放下'), findsOneWidget);

    // 切到设置页
    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    expect(find.text('后台监控'), findsOneWidget);
  });
}
