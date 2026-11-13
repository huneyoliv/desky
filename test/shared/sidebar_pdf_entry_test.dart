import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/shared/widgets/sidebar_nav.dart';

Future<void> _pumpSidebar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appTranslationProvider.overrideWith(
          (ref) => AppTranslationNotifier(ref)..state = const AppTranslation(languageCode: 'pt'),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        home: const Scaffold(
          body: Row(
            children: [
              SidebarNav(currentRoute: '/flashcards'),
              Expanded(child: SizedBox.expand()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('a sidebar tem Flashcards e Leitor de PDF como abas separadas', (tester) async {
    await _pumpSidebar(tester);

    // As duas abas coexistem: os flashcards nao foram substituidos pelo leitor.
    expect(find.text('Flashcards'), findsOneWidget);
    expect(find.text('Leitor de PDF'), findsOneWidget);

    final flashcardEntry = SidebarNav.items.where((e) => e.route == '/flashcards').toList();
    final readerEntry = SidebarNav.items.where((e) => e.route == '/smartbook').toList();

    expect(flashcardEntry, hasLength(1), reason: 'Flashcards mantem aba propria');
    expect(readerEntry, hasLength(1), reason: 'o leitor tem aba propria');
    expect(readerEntry.single.keyName, equals('pdf_reader_title'));
    expect(readerEntry.single.defaultTitle, equals('Leitor de PDF'));
    expect(readerEntry.single.fallbackIcon, equals(Icons.menu_book_rounded));
  });
}