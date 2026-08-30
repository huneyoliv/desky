import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desky/data/models/timelapse_session_model.dart';
import 'package:desky/features/timelapse/timelapse_notifier.dart';
import 'package:desky/features/timelapse/timelapse_gallery_screen.dart';
import 'package:desky/features/timelapse/timelapse_player_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Timelapse Model & Notifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('TimelapseSession toJson and fromJson roundtrip', () {
      final now = DateTime(2026, 8, 17, 10, 30);
      final session = TimelapseSession(
        id: 'tl_12345',
        subjectName: 'Matemática',
        subjectColorInt: 4292557552,
        startTime: now,
        durationSeconds: 1800,
        framePaths: ['/tmp/frame_00000.jpg', '/tmp/frame_00001.jpg'],
        thumbnailPath: '/tmp/frame_00000.jpg',
      );

      final json = session.toJson();
      final decoded = TimelapseSession.fromJson(json);

      expect(decoded.id, 'tl_12345');
      expect(decoded.subjectName, 'Matemática');
      expect(decoded.durationSeconds, 1800);
      expect(decoded.frameCount, 2);
      expect(decoded.thumbnailPath, '/tmp/frame_00000.jpg');
    });

    test('TimelapseNotifier starts and stops recording properly', () async {
      final container = ProviderContainer();
      final notifier = container.read(timelapseNotifierProvider.notifier);
      await notifier.loadSessions();

      notifier.startRecording(
        subjectName: 'Física',
        subjectColorInt: 4292557552,
      );

      final state = container.read(timelapseNotifierProvider);
      expect(state.isRecording, isTrue);
      expect(state.activeSubjectName, 'Física');

      final stopped = await notifier.stopRecording();
      expect(container.read(timelapseNotifierProvider).isRecording, isFalse);
      expect(stopped, isNotNull);
      container.dispose();
    });
  });

  group('Timelapse UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('TimelapseGalleryScreen renders empty state when no recordings exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: const TimelapseGalleryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Galeria de Timelapse'), findsOneWidget);
      expect(find.text('Nenhum timelapse gravado ainda'), findsOneWidget);
    });

    testWidgets('TimelapsePlayerDialog displays controls and playback speed buttons', (tester) async {
      final session = TimelapseSession(
        id: 'tl_999',
        subjectName: 'Química Orgânica',
        subjectColorInt: 4292557552,
        startTime: DateTime.now(),
        durationSeconds: 3600,
        framePaths: ['/mock/path/f1.jpg', '/mock/path/f2.jpg'],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => TimelapsePlayerDialog.show(context, session),
                  child: const Text('Open Player'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Player'));
      await tester.pumpAndSettle();

      expect(find.text('Química Orgânica'), findsAtLeastNWidgets(1));
      expect(find.text('10x'), findsOneWidget);
      expect(find.text('30x'), findsOneWidget);
    });
  });
}
