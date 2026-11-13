import 'dart:io';

import 'package:flutter/services.dart';

/// Recebe o caminho de um PDF aberto pelo Finder no macOS.
///
/// O `AppDelegate.swift` escuta os Apple Events de abertura de documento e
/// entrega o caminho por este canal. Em outras plataformas o caminho chega por
/// argumento de linha de comando e nada e registrado aqui.
class MacOsDocumentChannel {
  MacOsDocumentChannel._();

  static const MethodChannel channel = MethodChannel('dev.desky/documents');

  /// Registra o handler. Retorna `false` quando a plataforma nao usa o canal.
  static bool listen(void Function(String path) onOpen) {
    if (!Platform.isMacOS) return false;
    channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (call.method == 'openPdf' && args is String && args.trim().isNotEmpty) {
        onOpen(args.trim());
      }
      return null;
    });
    return true;
  }
}