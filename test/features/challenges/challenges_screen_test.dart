import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/challenge_model.dart';
import 'package:desky/data/repositories/challenge_repository.dart';
import 'package:desky/features/challenges/challenges_screen.dart';

class FakeChallengeRepository extends ChallengeRepository {
  final List<ChallengeModel> mockAvailable;
  final List<ChallengeModel> mockMy;

  FakeChallengeRepository({
    this.mockAvailable = const [],
    this.mockMy = const [],
  });

  @override
  Future<List<ChallengeModel>> fetchAvailableChallenges() async => mockAvailable;

  @override
  Future<List<ChallengeModel>> fetchMyChallenges() async => mockMy;

  @override
  Future<bool> joinChallenge(int challengeId, int flameBet) async => true;
}

void main() {
  testWidgets('ChallengesScreen renders available challenges and my challenges tab', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final available = [
      ChallengeModel(
        id: 101,
        name: 'Desafio 50 Horas',
        description: 'Meta de 50h de foco no mês',
        rules: 'Estude com o timer ligado',
        flameCost: 40,
        checkInMethod: 'timer',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        checkInCount: 0,
        successThreshold: 0.8,
        participantCount: 25,
        status: 'active',
        isJoined: false,
      ),
    ];

    final my = [
      ChallengeModel(
        id: 202,
        name: 'Meu Desafio Semanal',
        description: 'Estudo consistente por 7 dias',
        rules: 'Faça check-in diário',
        flameCost: 20,
        checkInMethod: 'timer',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        checkInCount: 3,
        successThreshold: 0.8,
        participantCount: 10,
        status: 'active',
        isJoined: true,
      ),
    ];

    final fakeRepo = FakeChallengeRepository(
      mockAvailable: available,
      mockMy: my,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          challengeRepositoryProvider.overrideWithValue(fakeRepo),
          appTranslationProvider.overrideWith(
            (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(
            splashFactory: InkRipple.splashFactory,
          ),
          home: const ChallengesScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Desafio 50 Horas'), findsOneWidget);

    // Switch to 'Meus Desafios' tab
    await tester.tap(find.text('Meus Desafios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Meu Desafio Semanal'), findsOneWidget);
  });
}
