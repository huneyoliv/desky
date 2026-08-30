import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/features/timer/widgets/subject_management_dialog.dart';

void main() {
  testWidgets('SubjectManagementDialog lists subjects and selects one', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final subjects = [
      const SubjectModel(
        id: 1,
        title: 'Matemática',
        colorInt: 4292557552,
        studyMs: 3600000,
      ),
      const SubjectModel(
        id: 2,
        title: 'História',
        colorInt: 4283215696,
        studyMs: 7200000,
      ),
    ];

    SubjectModel? selected;

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
              onSelectSubject: (sub) => selected = sub,
              onCreateSubject: (_, __) {},
              onUpdateSubject: (_) {},
              onArchiveSubject: (_, __) {},
              onDeleteSubject: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Matemática'), findsOneWidget);
    expect(find.text('História'), findsOneWidget);

    await tester.tap(find.text('História'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.id, equals(2));
    expect(selected!.title, equals('História'));
  });
}
