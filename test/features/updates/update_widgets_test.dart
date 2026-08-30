import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';
import 'package:desky/core/services/update_service.dart';
import 'package:desky/features/updates/models/update_model.dart';
import 'package:desky/features/updates/update_notifier.dart';
import 'package:desky/features/updates/widgets/update_button.dart';
import 'package:desky/features/updates/widgets/update_dialog.dart';
import 'package:dio/dio.dart';

class MockUpdateService extends UpdateService {
  final AppRelease? release;
  MockUpdateService({this.release});

  @override
  Future<AppRelease?> fetchLatestRelease({CancelToken? cancelToken}) async => release;
}

void main() {
  group('Update Widgets Tests', () {
    final sampleRelease = const AppRelease(
      id: 999,
      tagName: 'v1.5.0',
      name: 'Desky v1.5.0 - Super Speed',
      body: 'Features:\n- New super fast timer\n- Better group chat',
      htmlUrl: 'https://github.com/huneyoliv/desky/releases/tag/v1.5.0',
      assets: [
        ReleaseAsset(
          id: 101,
          name: 'Desky-Windows-Installer-x64.exe',
          size: 50000000,
          downloadUrl: 'https://github.com/test/download.exe',
          contentType: 'application/x-msdownload',
        ),
        ReleaseAsset(
          id: 102,
          name: 'Desky-Linux-x64.deb',
          size: 50000000,
          downloadUrl: 'https://github.com/test/download.deb',
          contentType: 'application/vnd.debian.binary-package',
        ),
        ReleaseAsset(
          id: 103,
          name: 'Desky-macOS-Installer.dmg',
          size: 50000000,
          downloadUrl: 'https://github.com/test/download.dmg',
          contentType: 'application/x-apple-diskimage',
        ),
      ],
    );

    testWidgets('UpdateButton renders badge with text and icon when update is available', (tester) async {
      final mockService = MockUpdateService(release: sampleRelease);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateServiceProvider.overrideWithValue(mockService),
            updateNotifierProvider.overrideWith((ref) {
              return UpdateNotifier(service: mockService, currentVersion: '1.0.0');
            }),
            appTranslationProvider.overrideWith(
              (ref) => AppTranslationNotifier(ref),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UpdateButton(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(UpdateButton), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.text('Atualização Disponível'), findsOneWidget);

      await tester.tap(find.byType(UpdateButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(UpdateDialog), findsOneWidget);
    });

    testWidgets('UpdateDialog renders changelog with Markdown formatting', (tester) async {
      const markdownRelease = AppRelease(
        id: 1000,
        tagName: 'v1.5.0',
        name: 'Desky v1.5.0 - Super Speed',
        body: '### ✨ Features\n- **Super Timer**: 10x faster\n- `AppConstants` updated\n\nVisit [GitHub](https://github.com/huneyoliv/desky)',
        htmlUrl: 'https://github.com/huneyoliv/desky/releases/tag/v1.5.0',
        assets: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appTranslationProvider.overrideWith(
              (ref) => AppTranslationNotifier(ref),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UpdateDialog(release: markdownRelease),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Atualização Disponível'), findsOneWidget);
      expect(find.text('v1.5.0'), findsOneWidget);
      expect(find.textContaining('Super Timer'), findsOneWidget);
      expect(find.textContaining('10x faster'), findsOneWidget);
      expect(find.text('Ver no GitHub'), findsOneWidget);
    });

    testWidgets('UpdateDialog renders fallback text when release body is empty', (tester) async {
      const emptyRelease = AppRelease(
        id: 1001,
        tagName: 'v1.6.0',
        name: 'Desky v1.6.0',
        body: '',
        htmlUrl: 'https://github.com/huneyoliv/desky/releases/tag/v1.6.0',
        assets: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appTranslationProvider.overrideWith(
              (ref) => AppTranslationNotifier(ref),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UpdateDialog(release: emptyRelease),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Melhorias de desempenho e correções gerais.'), findsOneWidget);
    });

    testWidgets('UpdateButton accepts custom height and padding', (tester) async {
      final mockService = MockUpdateService(release: sampleRelease);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateServiceProvider.overrideWithValue(mockService),
            updateNotifierProvider.overrideWith((ref) {
              return UpdateNotifier(service: mockService, currentVersion: '1.0.0');
            }),
            appTranslationProvider.overrideWith(
              (ref) => AppTranslationNotifier(ref),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UpdateButton(
                height: 22,
                padding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(UpdateButton), findsOneWidget);
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.text('Atualização Disponível'), findsOneWidget);
    });
  });
}
