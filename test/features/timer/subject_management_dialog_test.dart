import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/features/timer/widgets/subject_management_dialog.dart';

const _math = SubjectModel(
  id: 1,
  title: 'Matemática',
  colorInt: 4292557552,
  studyMs: 3600000,
);

const _history = SubjectModel(
  id: 2,
  title: 'História',
  colorInt: 4283215696,
  studyMs: 7200000,
);

Future<void> _pumpDialog(
  WidgetTester tester, {
  required List<SubjectModel> subjects,
  required ValueChanged<SubjectModel> onSelectSubject,
  required Future<SubjectModel?> Function(String title, int colorInt) onCreateSubject,
}) async {
  tester.view.physicalSize = const Size(1000, 700);
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
      child: MaterialApp(
        home: Scaffold(
          body: SubjectManagementDialog(
            subjects: subjects,
            selectedSubject: null,
            onSelectSubject: onSelectSubject,
            onCreateSubject: onCreateSubject,
            onUpdateSubject: (_) {},
            onArchiveSubject: (_, __) {},
            onDeleteSubject: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SubjectManagementDialog lists subjects and selects one', (tester) async {
    SubjectModel? selected;
    await _pumpDialog(
      tester,
      subjects: const [_math, _history],
      onSelectSubject: (sub) => selected = sub,
      onCreateSubject: (_, __) async => null,
    );

    expect(find.text('Matemática'), findsOneWidget);
    expect(find.text('História'), findsOneWidget);

    await tester.tap(find.text('História'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.id, equals(2));
    expect(selected!.title, equals('História'));
  });

  testWidgets('tapping the empty area of a row selects the subject', (tester) async {
    SubjectModel? selected;
    await _pumpDialog(
      tester,
      subjects: const [_math, _history],
      onSelectSubject: (sub) => selected = sub,
      onCreateSubject: (_, __) async => null,
    );

    // Taps outside the label, on the row's empty space: that was the dead zone of
    // the previous GestureDetector, which only responded where the Text painted.
    final titleRect = tester.getRect(find.text('História'));
    await tester.tapAt(Offset(titleRect.right + 60, titleRect.center.dy));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.id, equals(2));
  });

  testWidgets('a subject created from the dialog appears without reopening it', (tester) async {
    await _pumpDialog(
      tester,
      subjects: const [_math],
      onSelectSubject: (_) {},
      onCreateSubject: (title, colorInt) async =>
          SubjectModel(id: 3, title: title, colorInt: colorInt),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Nova Matéria'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Química');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Química'), findsOneWidget);
    expect(find.text('Matemática'), findsOneWidget);
  });

  testWidgets('a duplicate subject title is rejected and not created', (tester) async {
    var createCalls = 0;
    await _pumpDialog(
      tester,
      subjects: const [_math],
      onSelectSubject: (_) {},
      onCreateSubject: (_, __) async {
        createCalls++;
        return null;
      },
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Nova Matéria'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  matemática  ');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(createCalls, equals(0));
    expect(find.byType(AlertDialog), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.errorText, isNotNull);
  });

  testWidgets('an empty subject title is rejected and not created', (tester) async {
    var createCalls = 0;
    await _pumpDialog(
      tester,
      subjects: const [_math],
      onSelectSubject: (_) {},
      onCreateSubject: (_, __) async {
        createCalls++;
        return null;
      },
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Nova Matéria'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(createCalls, equals(0));
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
