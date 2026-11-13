import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/data/models/challenge_model.dart';
import 'package:desky/data/repositories/challenge_repository.dart';
import 'package:desky/features/challenges/challenges_screen.dart';

class FakeChallengeRepository extends ChallengeRepository {
  FakeChallengeRepository({this.mockAvailable = const []});

  final List<ChallengeModel> mockAvailable;

  @override
  Future<List<ChallengeModel>> fetchAvailableChallenges() async => mockAvailable;
}

ChallengeModel _challenge({int id = 101, String name = 'Desafio 50 Horas'}) {
  return ChallengeModel(
    id: id,
    name: name,
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
  );
}

Future<void> _pump(WidgetTester tester, FakeChallengeRepository repo) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        challengeRepositoryProvider.overrideWithValue(repo),
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: const ChallengesScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('a aba lista os desafios disponiveis em modo somente leitura', (tester) async {
    await _pump(tester, FakeChallengeRepository(mockAvailable: [_challenge()]));

    expect(find.text('Desafio 50 Horas'), findsOneWidget);

    // Acoes removidas: rotas join/cancel/my nao existem na API (404).
    expect(find.text('Participar do Desafio'), findsNothing);
    expect(find.text('Fazer Check-in'), findsNothing);
    expect(find.text('Meus Desafios'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('estado vazio explica que a lista e somente consulta', (tester) async {
    await _pump(tester, FakeChallengeRepository());

    expect(find.text('Nenhum desafio disponível no momento.'), findsOneWidget);
    expect(
      find.textContaining('somente para consulta'),
      findsOneWidget,
      reason: 'o estado vazio precisa deixar claro que participar nao e suportado',
    );
    expect(find.text('Participar do Desafio'), findsNothing);
  });
}