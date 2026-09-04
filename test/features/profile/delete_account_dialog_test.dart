import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/features/profile/widgets/delete_account_dialog.dart';

void main() {
  testWidgets('DeleteAccountDialog requires typing "delete" to enable confirmation', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DeleteAccountDialog(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dialog loaded and asks for "delete"
    expect(find.textContaining('"delete"'), findsOneWidget);

    // Confirm button should initially be disabled
    final buttonFinder = find.byType(ElevatedButton);
    expect(buttonFinder, findsOneWidget);
    ElevatedButton button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull);

    // Check the consent checkbox
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    // Still disabled because text is empty
    button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull);

    // Enter wrong text
    await tester.enterText(find.byType(TextField), 'excluir');
    await tester.pumpAndSettle();
    button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNull);

    // Enter "delete"
    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pumpAndSettle();
    button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNotNull);

    // Also works with "DELETE" uppercase
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pumpAndSettle();
    button = tester.widget<ElevatedButton>(buttonFinder);
    expect(button.onPressed, isNotNull);
  });
}
