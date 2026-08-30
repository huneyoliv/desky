import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/theme/app_text_styles.dart';
import 'package:desky/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Font asset files can be loaded from bundle', () async {
    final sfText = await rootBundle.load('assets/fonts/SF-Pro-Text-Regular.otf');
    expect(sfText.lengthInBytes, greaterThan(0));

    final sfDisplay = await rootBundle.load('assets/fonts/SF-Pro-Display-Bold.otf');
    expect(sfDisplay.lengthInBytes, greaterThan(0));

    final emoji = await rootBundle.load('assets/fonts/AppleEmoji.ttf');
    expect(emoji.lengthInBytes, greaterThan(0));
  });

  test('AppTheme darkTheme configures fontFamily and textTheme properly', () {
    final theme = AppTheme.darkTheme;
    expect(theme.textTheme.bodyMedium?.fontFamily, equals(AppTextStyles.fontText));
  });
}
