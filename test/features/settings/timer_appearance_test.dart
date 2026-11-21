import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/theme/app_text_styles.dart';
import 'package:desky/core/theme/timer_appearance.dart';
import 'package:desky/data/repositories/settings_repository.dart';
import 'package:desky/features/settings/settings_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repository persists and normalizes timer appearance', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = SettingsRepository(prefs: prefs);

    expect(await repo.getTimerBackground(), timerBackgroundTheme);
    expect(await repo.getTimerFont(), timerFontDigital);
    expect(await repo.getTimerBackgroundImagePath(), isNull);

    await repo.saveTimerBackground(timerBackgroundAurora);
    await repo.saveTimerFont(timerFontPretendard);
    await repo.saveTimerBackgroundImagePath('C:\\images\\study.png');

    expect(await repo.getTimerBackground(), timerBackgroundAurora);
    expect(await repo.getTimerFont(), timerFontPretendard);
    expect(await repo.getTimerBackgroundImagePath(), 'C:\\images\\study.png');

    await repo.saveTimerBackground('invalid');
    await repo.saveTimerFont('invalid');
    await repo.saveTimerBackgroundImagePath('  ');

    expect(await repo.getTimerBackground(), timerBackgroundTheme);
    expect(await repo.getTimerFont(), timerFontDigital);
    expect(await repo.getTimerBackgroundImagePath(), isNull);
  });

  test('notifier hydrates and updates appearance preferences', () async {
    SharedPreferences.setMockInitialValues({
      SettingsRepository.keyTimerBackground: timerBackgroundSunset,
      SettingsRepository.keyTimerFont: timerFontSfPro,
      SettingsRepository.keyTimerBackgroundImagePath: 'C:\\images\\old.png',
    });
    final prefs = await SharedPreferences.getInstance();
    final notifier = SettingsNotifier(SettingsRepository(prefs: prefs));
    addTearDown(notifier.dispose);
    await notifier.init();

    expect(notifier.state.timerBackground, timerBackgroundSunset);
    expect(notifier.state.timerFont, timerFontSfPro);
    expect(notifier.state.timerBackgroundImagePath, 'C:\\images\\old.png');

    await notifier.setTimerBackground(timerBackgroundAurora);
    await notifier.setTimerFont(timerFontPretendard);
    await notifier.setTimerBackgroundImage('C:\\images\\new.png');

    expect(notifier.state.timerBackground, timerBackgroundCustomImage);
    expect(notifier.state.timerFont, timerFontPretendard);
    expect(prefs.getString(SettingsRepository.keyTimerBackground),
        timerBackgroundCustomImage);
    expect(prefs.getString(SettingsRepository.keyTimerBackgroundImagePath),
        'C:\\images\\new.png');
    expect(prefs.getString(SettingsRepository.keyTimerFont),
        timerFontPretendard);
  });

  test('file validation accepts PNG and rejects invalid inputs', () async {
    final directory = Directory('build/test_timer_appearance_validation');
    await directory.create(recursive: true);
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    final png = File('${directory.path}/valid.png');
    await png.writeAsBytes(bytes);
    final bmp = File('${directory.path}/invalid.bmp');
    await bmp.writeAsBytes(bytes);
    final empty = File('${directory.path}/empty.png');
    await empty.writeAsBytes(const []);
    final large = File('${directory.path}/large.jpg');
    await large.writeAsBytes(List<int>.filled(21, 1));

    expect(await isValidTimerBackgroundImageFile(png.path), isTrue);
    expect(await isValidTimerBackgroundImageFile(bmp.path), isFalse);
    expect(await isValidTimerBackgroundImageFile(empty.path), isFalse);
    expect(
      await isValidTimerBackgroundImageFile(large.path, maxBytes: 20),
      isFalse,
    );
    expect(
      await isValidTimerBackgroundImageFile('${directory.path}/missing.png'),
      isFalse,
    );
  });

  test('font selection uses bundled families and safe default', () {
    expect(timerFontFamilyName(timerFontDigital), AppTextStyles.fontTimer);
    expect(timerFontFamilyName(timerFontSfPro), AppTextStyles.fontDisplay);
    expect(timerFontFamilyName(timerFontPretendard), 'Pretendard');
    expect(timerFontFamilyName('invalid'), AppTextStyles.fontTimer);
  });
}
