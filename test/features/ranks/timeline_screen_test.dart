import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/repositories/rank_repository.dart';
import 'package:desky/features/ranks/session_derivations.dart';
import 'package:desky/features/ranks/widgets/timeline_tab.dart';
import 'package:desky/features/settings/settings_notifier.dart';

class _FakeRankRepository extends RankRepository {
  final Map<String, List<StudySession>> responses;
  final List<Map<String, dynamic>> calls = [];

  _FakeRankRepository(this.responses);

  @override
  Future<List<StudySession>> fetchStudySessions({
    required int userId,
    required String startDate,
    required String endDate,
  }) async {
    calls.add({'userId': userId, 'startDate': startDate, 'endDate': endDate});
    return responses[endDate] ?? [];
  }
}

StudySession _session(String day, int start, int minutes, String subject) {
  return StudySession(
    day: day,
    startMinute: start,
    durationMs: minutes * 60000,
    subject: subject,
  );
}

Future<void> _pump(
  WidgetTester tester,
  _FakeRankRepository repository,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)
            ..state = const AppTranslation(languageCode: 'pt'),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TimelineTab(repository: repository, userId: 42),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('renders chronological sessions, total and derived gaps',
      (tester) async {
    final day = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final repo = _FakeRankRepository({
      day: [
        _session(day, 9 * 60, 15, 'Física'),
        _session(day, 8 * 60, 30, 'Física'),
      ],
    });
    tester.view.physicalSize = const Size(640, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pump(tester, repo);

    expect(repo.calls.single['userId'], 42);
    expect(repo.calls.single['startDate'], day);
    expect(repo.calls.single['endDate'], day);
    expect(find.text('Física'), findsNWidgets(2));
    expect(find.text('08:00–08:30'), findsOneWidget);
    expect(find.text('09:00–09:15'), findsOneWidget);
    expect(find.textContaining('45min'), findsWidgets);
    expect(
      find.text('Intervalo derivado entre sessões: 08:30–09:00 (30min)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('next day requests and shows an empty state', (tester) async {
    final today = DateTime.now();
    final day = DateFormat('yyyy-MM-dd').format(today);
    final tomorrow = DateFormat('yyyy-MM-dd').format(
      today.add(const Duration(days: 1)),
    );
    final repo = _FakeRankRepository({
      day: [_session(day, 600, 20, 'Física')],
    });
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Próximo dia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.calls.last['startDate'], tomorrow);
    expect(repo.calls.last['endDate'], tomorrow);
    expect(find.text('Nenhuma sessão de estudo neste dia.'), findsOneWidget);
  });
}
