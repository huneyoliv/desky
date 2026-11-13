import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/theme/app_colors.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/features/timer/widgets/subject_management_dialog.dart';
import 'package:desky/features/timer/widgets/subject_selector.dart';

const _math = SubjectModel(id: 1, title: 'Matemática', colorInt: 0xFF7C3AED);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectThemeTextColour(WidgetTester tester, String label) {
  final names = tester.widgetList<Text>(find.text(label));
  expect(names, isNotEmpty, reason: 'o nome "$label" precisa estar visivel');
  for (final name in names) {
    // Same colour ranking rows use, instead of the subject colour or pure white.
    expect(name.style?.color, equals(AppColors.textPrimary));
  }
}

void main() {
  testWidgets('the subject selection dialog follows the theme text colour', (tester) async {
    await _pump(
      tester,
      SubjectManagementDialog(
        subjects: const [_math],
        selectedSubject: null,
        onSelectSubject: (_) {},
        onCreateSubject: (_, __) async => null,
        onUpdateSubject: (_) {},
        onArchiveSubject: (_, __) {},
        onDeleteSubject: (_) {},
      ),
    );

    _expectThemeTextColour(tester, 'Matemática');
  });

  testWidgets('the subject management list follows the theme text colour', (tester) async {
    await _pump(
      tester,
      SubjectSelector(
        subjects: const [_math],
        selectedSubject: null,
        onSelectSubject: (_) {},
        onCreateSubject: (_, __) {},
      ),
    );

    await tester.tap(find.byIcon(Icons.tune_outlined));
    await tester.pumpAndSettle();

    _expectThemeTextColour(tester, 'Matemática');
  });
}
