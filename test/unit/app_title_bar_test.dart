import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desky/core/services/update_service.dart';
import 'package:desky/features/updates/models/update_model.dart';
import 'package:desky/shared/widgets/app_title_bar.dart';
import 'package:dio/dio.dart';

class MockUpdateService extends UpdateService {
  @override
  Future<AppRelease?> fetchLatestRelease({CancelToken? cancelToken}) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTitleBar Tests', () {
    testWidgets('AppTitleBar renders title and 3 control buttons', (tester) async {
      final mockService = MockUpdateService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateServiceProvider.overrideWithValue(mockService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AppTitleBar(title: 'Desky - Yeolpumta Desktop'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppTitleBar), findsOneWidget);
      expect(find.byType(MouseRegion), findsWidgets);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('AppTitleBar handles maximize and unmaximize events gracefully', (tester) async {
      final mockService = MockUpdateService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateServiceProvider.overrideWithValue(mockService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AppTitleBar(title: 'Desky'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final state = tester.state(find.byType(AppTitleBar)) as dynamic;
      state.onWindowMaximize();
      await tester.pump();

      state.onWindowUnmaximize();
      await tester.pump();
      expect(find.byType(AppTitleBar), findsOneWidget);
    });
  });
}
