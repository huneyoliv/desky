import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('dial colours and visibility default sensibly and persist', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs: prefs);
    final n = SettingsNotifier(repo);
    await n.init();
    expect(n.state.dialStudyColor, 0xFFFF6B1A);
    expect(n.state.dialBreakColor, 0xFF2F7CF6);
    expect(n.state.showStopwatchDial, isTrue);

    await n.setDialStyle(study: 0xFF30D158);
    await n.setDialStyle(rest: 0xFFAF52DE, show: false);
    final again = SettingsNotifier(repo);
    await again.init();
    expect(again.state.dialStudyColor, 0xFF30D158);
    expect(again.state.dialBreakColor, 0xFFAF52DE);
    expect(again.state.showStopwatchDial, isFalse);
  });
}
