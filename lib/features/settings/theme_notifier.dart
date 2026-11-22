import 'package:flutter/widgets.dart';
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
  static const String systemThemeId = 'system';

  final SettingsRepository _repository;
  bool _userExplicitlySet = false;
  bool _systemMode = false;
  String _darkThemeId = 'amoled_lilac';
  String _lightThemeId = 'daylight_lilac';

  ThemeNotifier(this._repository)
      : super(DeskyThemePalette.fromId(
          _repository.getInitialThemePresetId(),
        )) {
    _systemMode = _repository.getInitialThemePresetId() == systemThemeId;
    _init();
  }

  bool get isSystemMode => _systemMode;
  String get darkThemeId => _darkThemeId;
  String get lightThemeId => _lightThemeId;

  Future<void> _init() async {
    try {
      final savedId = await _repository.getThemePresetId();
      final darkId = await _repository.getDarkThemePresetId();
      final lightId = await _repository.getLightThemePresetId();
      if (!mounted || _userExplicitlySet) return;
      _darkThemeId = DeskyThemePalette.fromId(darkId).id;
      _lightThemeId = DeskyThemePalette.fromId(lightId).id;
      _systemMode = savedId == systemThemeId;
      if (_systemMode) {
        updateSystemBrightness();
      } else {
        state = DeskyThemePalette.fromId(savedId);
      }
    } catch (_) {}
  }

  /// Reapplies the persisted pair whenever the operating system brightness
  /// changes. Explicit palettes never react to this callback.
  void updateSystemBrightness() {
    if (!_systemMode || !mounted) return;
    final light = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.light;
    state = DeskyThemePalette.fromId(light ? _lightThemeId : _darkThemeId);
  }

  Future<void> setSystemTheme() async {
    _userExplicitlySet = true;
    _systemMode = true;
    if (state.isLight) {
      _lightThemeId = state.id;
    } else {
      _darkThemeId = state.id;
    }
    updateSystemBrightness();
    await _repository.saveSystemThemePresetIds(
      darkId: _darkThemeId,
      lightId: _lightThemeId,
    );
    await _repository.saveThemePresetId(systemThemeId);
  }

  Future<void> setTheme(DeskyThemePalette palette) async {
    _userExplicitlySet = true;
    _systemMode = false;
    state = palette;
    if (palette.isLight) {
      _lightThemeId = palette.id;
    } else {
      _darkThemeId = palette.id;
    }
    try {
      await _repository.saveSystemThemePresetIds(
        darkId: _darkThemeId,
        lightId: _lightThemeId,
      );
      await _repository.saveThemePresetId(palette.id);
    } catch (_) {}
  }

  Future<void> setThemeById(String themeId) async {
    if (themeId == systemThemeId) {
      await setSystemTheme();
      return;
    }
    await setTheme(DeskyThemePalette.fromId(themeId));
  }
}
