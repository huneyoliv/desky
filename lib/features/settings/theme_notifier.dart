import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_palette.dart';
import '../../data/repositories/settings_repository.dart';
import 'settings_notifier.dart';

final themeNotifierProvider =
    StateNotifierProvider<ThemeNotifier, DeskyThemePalette>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return ThemeNotifier(repo);
});

class ThemeNotifier extends StateNotifier<DeskyThemePalette> {
  final SettingsRepository _repository;
  bool _userExplicitlySet = false;

  ThemeNotifier(this._repository)
      : super(DeskyThemePalette.fromId(_repository.getInitialThemePresetId())) {
    _init();
  }

  Future<void> _init() async {
    try {
      final savedId = await _repository.getThemePresetId();
      if (mounted && !_userExplicitlySet) {
        state = DeskyThemePalette.fromId(savedId);
      }
    } catch (_) {}
  }

  Future<void> setTheme(DeskyThemePalette palette) async {
    _userExplicitlySet = true;
    state = palette;
    try {
      await _repository.saveThemePresetId(palette.id);
    } catch (_) {}
  }

  Future<void> setThemeById(String themeId) async {
    final palette = DeskyThemePalette.fromId(themeId);
    await setTheme(palette);
  }
}
