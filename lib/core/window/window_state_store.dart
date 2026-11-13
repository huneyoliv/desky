import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia do tamanho/estado da janela entre execucoes.
///
/// Guarda a largura, a altura e se a janela estava maximizada. Valores
/// corrompidos nao quebram a abertura: quem consome trata `null` como "sem
/// estado salvo" (ver `resolveWindowState`).
class WindowStateStore {
  WindowStateStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const String keyWidth = 'window_width';
  static const String keyHeight = 'window_height';
  static const String keyMaximized = 'window_maximized';

  final SharedPreferences? _prefs;

  Future<SharedPreferences?> _resolvePrefs() async {
    if (_prefs != null) return _prefs;
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  /// Tamanho salvo, ou `null` quando ausente/invalido.
  Future<Size?> readSize() async {
    final prefs = await _resolvePrefs();
    if (prefs == null) return null;
    final width = prefs.getDouble(keyWidth);
    final height = prefs.getDouble(keyHeight);
    if (width == null || height == null) return null;
    if (!width.isFinite || !height.isFinite) return null;
    if (width <= 0 || height <= 0) return null;
    return Size(width, height);
  }

  Future<bool> readMaximized() async {
    final prefs = await _resolvePrefs();
    return prefs?.getBool(keyMaximized) ?? false;
  }

  Future<void> save({required Size size, required bool maximized}) async {
    final prefs = await _resolvePrefs();
    if (prefs == null) return;
    try {
      if (size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0) {
        await prefs.setDouble(keyWidth, size.width);
        await prefs.setDouble(keyHeight, size.height);
      }
      await prefs.setBool(keyMaximized, maximized);
    } catch (_) {}
  }
}