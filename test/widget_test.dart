import 'package:flutter_test/flutter_test.dart';
import 'package:is_it_enough/app.dart';
import 'package:is_it_enough/features/settings/data/repositories/settings_repository.dart';
import 'package:is_it_enough/shared/services/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Settings page renders', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final prefs = await SharedPreferences.getInstance();
    final settingsService = SettingsService(SettingsRepository(prefs));

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: settingsService,
        child: const IsItEnoughApp(),
      ),
    );

    expect(find.text('够了吗'), findsWidgets);
    expect(find.text('现在放下'), findsOneWidget);
    expect(find.text('后台监控'), findsOneWidget);
  });
}
