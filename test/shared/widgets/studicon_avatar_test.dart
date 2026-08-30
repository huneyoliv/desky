import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/shared/widgets/studicon_avatar.dart';
import 'package:desky/core/cdn/cdn_resolver.dart';

void main() {
  group('StudiconAvatar Widget Tests', () {
    testWidgets('renders local asset directly when studiconId is <= 0 or -1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudiconAvatar(
              studiconId: -1,
              pose: StudiconPose.normal1,
              isStudying: true,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, equals('assets/images/studicon/ic_user_on_s.png'));
    });

    testWidgets('renders ic_user_off_s when studiconId is <= 0 and isStudying is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudiconAvatar(
              studiconId: 0,
              pose: StudiconPose.normal1,
              isStudying: false,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, equals('assets/images/studicon/ic_user_off_s.png'));
    });

    testWidgets('renders ic_user_sweat_s for sweat poses on default studicon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudiconAvatar(
              studiconId: -1,
              pose: StudiconPose.sweat2,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, equals('assets/images/studicon/ic_user_sweat_s.png'));
    });

    testWidgets('renders ic_user_fire_s for fire and explosion poses on default studicon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudiconAvatar(
              studiconId: -1,
              pose: StudiconPose.fire1,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, equals('assets/images/studicon/ic_user_fire_s.png'));
    });

    testWidgets('renders ic_user_smoke_s for paused/smoke poses on default studicon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudiconAvatar(
              studiconId: -1,
              pose: StudiconPose.smoke1,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect((imageWidget.image as AssetImage).assetName, equals('assets/images/studicon/ic_user_smoke_s.png'));
    });
  });
}
