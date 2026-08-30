import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/cdn/cdn_resolver.dart';
import 'package:desky/shared/widgets/studicon_avatar.dart';

void main() {
  testWidgets('StudiconAvatar builds correctly with given size and pose', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StudiconAvatar(
            studiconId: 5,
            pose: StudiconPose.sweat1,
            size: 64,
          ),
        ),
      ),
    );

    expect(find.byType(StudiconAvatar), findsOneWidget);
  });
}
