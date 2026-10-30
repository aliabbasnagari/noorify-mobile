import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/settings/settings_models.dart';
import 'package:noorify/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('theme mode defaults to dark when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final controller =
        SettingsController(await SharedPreferences.getInstance());
    expect(controller.themeMode, AppThemeMode.dark);
  });

  test('setThemeMode persists and a new controller reads it back', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(prefs);

    await controller.setThemeMode(AppThemeMode.light);
    expect(controller.themeMode, AppThemeMode.light);

    final reloaded = SettingsController(await SharedPreferences.getInstance());
    expect(reloaded.themeMode, AppThemeMode.light);
  });

  test('an invalid stored value falls back to dark', () async {
    SharedPreferences.setMockInitialValues({'settings.themeMode': 'bogus'});
    final controller =
        SettingsController(await SharedPreferences.getInstance());
    expect(controller.themeMode, AppThemeMode.dark);
  });
}
