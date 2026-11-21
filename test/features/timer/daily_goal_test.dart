import 'package:desky/data/models/subject_model.dart';
import 'package:desky/data/repositories/subject_repository.dart';
import 'package:desky/data/repositories/timer_repository.dart';
import 'package:desky/features/timer/timer_notifier.dart';
import 'package:desky/features/timer/timer_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Subjects extends SubjectRepository {
  @override
  Future<SubjectFetchResult> fetchSubjectsData({String? language, String? timezone, int? version}) async =>
      const SubjectFetchResult(subjects: [SubjectModel(id: 1, title: 'GS1', colorInt: 1)], todayTotalMs: 0);
}

void main() {
  test('the daily goal is saved, clamped, and comes back after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    TimerNotifier make() => TimerNotifier(
          timerRepository: TimerRepository(),
          subjectRepository: _Subjects(),
          sessionStore: TimerSessionStore(prefs: prefs),
        );
    final a = make();
    await a.ready;
    expect(a.state.dailyGoalMinutes, 360);
    await a.setDailyGoalMinutes(8 * 60);
    expect(a.state.dailyGoalMinutes, 480);
    await a.setDailyGoalMinutes(1);
    expect(a.state.dailyGoalMinutes, 15);
    await a.setDailyGoalMinutes(10 * 60);
    a.dispose();

    final b = make();
    await b.ready;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(b.state.dailyGoalMinutes, 600);
    b.dispose();
  });
}
