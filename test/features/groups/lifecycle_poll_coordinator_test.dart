import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/features/groups/lifecycle_poll_coordinator.dart';

void main() {
  group('LifecyclePollCoordinator', () {
    late int resumeCount;
    late int backgroundCount;
    late LifecyclePollCoordinator coordinator;

    setUp(() {
      resumeCount = 0;
      backgroundCount = 0;
      coordinator = LifecyclePollCoordinator(
        onResume: () => resumeCount++,
        onBackground: () => backgroundCount++,
      );
    });

    tearDown(() => coordinator.detach());

    test('resumed retoma e pede refresh imediato', () {
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(resumeCount, equals(1));
      expect(backgroundCount, equals(0));
    });

    test('hidden (minimizado) pausa os polls', () {
      coordinator.didChangeAppLifecycleState(AppLifecycleState.hidden);

      expect(backgroundCount, equals(1));
      expect(resumeCount, equals(0));
    });

    test('paused e detached tambem pausam', () {
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
      coordinator.didChangeAppLifecycleState(AppLifecycleState.detached);

      expect(backgroundCount, equals(2));
    });

    test('inactive (perda de foco) mantem os polls', () {
      coordinator.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(backgroundCount, equals(0));
      expect(resumeCount, equals(0));
    });

    test('ida e volta: pausa uma vez e retoma uma vez', () {
      coordinator.didChangeAppLifecycleState(AppLifecycleState.hidden);
      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(backgroundCount, equals(1));
      expect(resumeCount, equals(1));
    });

    testWidgets('attach e idempotente e detach limpa o registro',
        (tester) async {
      expect(coordinator.isAttached, isFalse);

      coordinator.attach();
      expect(coordinator.isAttached, isTrue);

      coordinator.attach(); // segunda chamada nao duplica
      expect(coordinator.isAttached, isTrue);

      coordinator.detach();
      expect(coordinator.isAttached, isFalse);

      coordinator.detach(); // idempotente
      expect(coordinator.isAttached, isFalse);
    });

    testWidgets('o observer registrado processa o ciclo real do binding',
        (tester) async {
      coordinator.attach();

      // O framework entrega o estado ao observer registrado.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(backgroundCount, equals(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(resumeCount, equals(1));

      coordinator.detach();

      // Depois do detach, o ciclo nao deve mais chegar ao coordenador.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      expect(backgroundCount, equals(1));
    });
  });
}