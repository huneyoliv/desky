import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desky/features/smartbook/smartbook_screen.dart';
import 'package:desky/core/services/smartbook_window_service.dart';

void main() {
  group('SmartBook Tests', () {
    testWidgets('SmartBookScreen renders empty view when no file is loaded', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: const SmartBookScreen(),
          ),
        ),
      );

      expect(find.text('Leitor de PDF'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
      expect(find.text('Selecionar Arquivo PDF'), findsOneWidget);
    });

    testWidgets('SmartBookWindowService open pushes fullscreen route', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SmartBookWindowService.open(context),
                child: const Text('Open Leitor de PDF'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Leitor de PDF'));
      await tester.pumpAndSettle();

      expect(find.byType(SmartBookScreen), findsOneWidget);
    });
  });
}
