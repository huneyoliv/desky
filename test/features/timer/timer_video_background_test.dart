import 'dart:async';

import 'package:desky/features/timer/widgets/timer_video_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements TimerVideoBackend {
  _FakeBackend();

  final calls = <String>[];
  final errorController = StreamController<Object?>.broadcast();
  bool failOpen = false;
  Completer<void>? openCompleter;
  int disposeCalls = 0;

  @override
  Stream<Object?> get errors => errorController.stream;

  @override
  Future<void> open(String path) async {
    calls.add('open:$path');
    if (failOpen) throw StateError('invalid media');
    if (openCompleter != null) await openCompleter!.future;
  }

  @override
  Future<void> setMuted(bool value) async {
    calls.add('mute:$value');
  }

  @override
  Future<void> setLooping(bool value) async {
    calls.add('loop:$value');
  }

  @override
  Future<void> play() async {
    calls.add('play');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    calls.add('dispose');
    await errorController.close();
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: Key('fake-video-frame'),
      color: Color(0xFF000000),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(String path, _FakeBackend backend, {Duration? openTimeout}) {
    return MaterialApp(
      home: TimerVideoBackground(
        path: path,
        backendFactory: () => backend,
        openTimeout: openTimeout ?? const Duration(seconds: 1),
        fallback: const ColoredBox(
          key: Key('static-fallback'),
          color: Color(0xFF123456),
        ),
      ),
    );
  }

  testWidgets('configures mute and loop before playing', (tester) async {
    final backend = _FakeBackend();
    await tester.pumpWidget(host('focus.mp4', backend));
    await tester.pumpAndSettle();

    expect(backend.calls.indexOf('mute:true'),
        lessThan(backend.calls.indexOf('play')));
    expect(backend.calls.indexOf('loop:true'),
        lessThan(backend.calls.indexOf('play')));
    expect(backend.calls, contains('open:focus.mp4'));
    expect(find.byKey(const Key('fake-video-frame')), findsOneWidget);
    expect(find.byKey(const Key('static-fallback')), findsOneWidget);
  });

  testWidgets('keeps static fallback when opening fails', (tester) async {
    final backend = _FakeBackend()..failOpen = true;
    await tester.pumpWidget(host('broken.mp4', backend));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-video-frame')), findsNothing);
    expect(find.byKey(const Key('static-fallback')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(backend.disposeCalls, 1);
  });

  testWidgets('a playback error returns to the fallback', (tester) async {
    final backend = _FakeBackend();
    await tester.pumpWidget(host('focus.mp4', backend));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fake-video-frame')), findsOneWidget);

    backend.errorController.add(StateError('decoder'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-video-frame')), findsNothing);
    expect(find.byKey(const Key('static-fallback')), findsOneWidget);
  });

  testWidgets('hidden pauses, inactive keeps playing and resumed resumes',
      (tester) async {
    final backend = _FakeBackend();
    await tester.pumpWidget(host('focus.mp4', backend));
    await tester.pumpAndSettle();
    backend.calls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(backend.calls, isNot(contains('pause')));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('pause'));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(backend.calls, contains('play'));
  });

  testWidgets('detached and route removal dispose the backend', (tester) async {
    final backend = _FakeBackend();
    await tester.pumpWidget(host('focus.mp4', backend));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    await tester.pumpAndSettle();
    expect(backend.disposeCalls, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(backend.disposeCalls, 1);
  });

  testWidgets('a stale asynchronous open cannot resurrect the old video',
      (tester) async {
    final first = _FakeBackend()..openCompleter = Completer<void>();
    final second = _FakeBackend();
    await tester.pumpWidget(
      MaterialApp(
        home: TimerVideoBackground(
          path: 'first.mp4',
          backendFactory: () => first,
          fallback: const ColoredBox(
              key: Key('static-fallback'), color: Color(0xFF123456)),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TimerVideoBackground(
          path: 'second.mp4',
          backendFactory: () => second,
          fallback: const ColoredBox(
              key: Key('static-fallback'), color: Color(0xFF123456)),
        ),
      ),
    );
    first.openCompleter!.complete();
    await tester.pumpAndSettle();

    expect(first.disposeCalls, 1);
    expect(first.calls, isNot(contains('play')));
    expect(second.calls, contains('open:second.mp4'));
  });

  testWidgets('opening timeout keeps fallback and disposes the backend',
      (tester) async {
    final backend = _FakeBackend()..openCompleter = Completer<void>();
    await tester.pumpWidget(host('slow.mp4', backend,
        openTimeout: const Duration(milliseconds: 1)));
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byKey(const Key('static-fallback')), findsOneWidget);
    expect(find.byKey(const Key('fake-video-frame')), findsNothing);
    expect(backend.disposeCalls, 1);
  });
}
