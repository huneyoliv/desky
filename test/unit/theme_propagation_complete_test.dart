import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desky/core/theme/app_colors.dart';
import 'package:desky/core/theme/app_theme.dart';
import 'package:desky/shared/widgets/subject_chip.dart';
import 'package:desky/data/models/subject_model.dart';
import 'package:desky/features/notifications/widgets/notification_bell.dart';
import 'package:desky/data/repositories/notification_repository.dart';

class _FakeNotificationRepository implements NotificationRepository {
  @override
  Future<int> fetchUnreadCount() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Theme Propagation Completeness Tests', () {
    test('all 5 presets have valid, non-transparent core colors', () {
      for (final preset in DeskyThemePalette.presets) {
        expect(preset.primary.alpha, greaterThan(0));
        expect(preset.background.alpha, greaterThan(0));
        expect(preset.surface.alpha, greaterThan(0));
        expect(preset.card.alpha, greaterThan(0));
        expect(preset.border.alpha, greaterThan(0));
        expect(preset.textPrimary.alpha, greaterThan(0));
        expect(preset.textSecondary.alpha, greaterThan(0));
        expect(preset.textMuted.alpha, greaterThan(0));
        expect(preset.heatmapL1.alpha, greaterThan(0));
        expect(preset.heatmapL2.alpha, greaterThan(0));
        expect(preset.heatmapL3.alpha, greaterThan(0));
        expect(preset.heatmapL4.alpha, greaterThan(0));
      }
    });

    test('each preset provides distinct primary and background colors', () {
      final lilac = DeskyThemePalette.amoledLilac;
      final emerald = DeskyThemePalette.forestEmerald;
      final amber = DeskyThemePalette.sunsetAmber;
      final navy = DeskyThemePalette.midnightNavy;
      final neon = DeskyThemePalette.cyberpunk;

      expect(emerald.primary, isNot(equals(lilac.primary)));
      expect(amber.primary, isNot(equals(lilac.primary)));
      expect(navy.primary, isNot(equals(lilac.primary)));
      expect(neon.primary, isNot(equals(lilac.primary)));

      expect(navy.background, isNot(equals(lilac.background)));
      expect(neon.card, isNot(equals(lilac.card)));
    });

    testWidgets('DeskyThemeContext extensions return active palette across all presets', (tester) async {
      for (final preset in DeskyThemePalette.presets) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.buildTheme(preset),
            home: Builder(
              builder: (context) {
                expect(context.palette.id, equals(preset.id));
                expect(context.appPrimary, equals(preset.primary));
                expect(context.appBackground, equals(preset.background));
                expect(context.appSurface, equals(preset.surface));
                expect(context.appCard, equals(preset.card));
                expect(context.appBorder, equals(preset.border));
                expect(context.appTextPrimary, equals(preset.textPrimary));
                expect(context.appTextSecondary, equals(preset.textSecondary));
                expect(context.appTextMuted, equals(preset.textMuted));
                expect(context.appHeatmapL1, equals(preset.heatmapL1));
                expect(context.appHeatmapL4, equals(preset.heatmapL4));
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
    });

    testWidgets('SubjectChip adapts to dynamic theme surface and text tokens', (tester) async {
      final subject = SubjectModel(
        id: 1,
        title: 'Matemática',
        colorInt: 0xFF3B82F6,
        studyMs: 3600000,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(DeskyThemePalette.forestEmerald),
          home: Scaffold(
            body: SubjectChip(
              subject: subject,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Matemática'), findsOneWidget);
      expect(find.text('1h 0m'), findsOneWidget);
    });

    testWidgets('NotificationBell renders with dynamic context colors without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationRepositoryProvider.overrideWithValue(_FakeNotificationRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.buildTheme(DeskyThemePalette.sunsetAmber),
            home: const Scaffold(
              body: NotificationBell(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotificationBell), findsOneWidget);
    });
  });
}
