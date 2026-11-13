import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Encaminha um arquivo (ou qualquer texto) para a instancia ja aberta.
///
/// Estrategia: a primeira instancia mantem um arquivo de trava exclusivo e um
/// servidor TCP em `127.0.0.1` numa porta efemera, cuja porta e publicada num
/// arquivo ao lado da trava. Uma segunda instancia nao consegue a trava, le a
/// porta e envia o caminho por socket, depois encerra.
///
/// Windows e Linux apenas: no macOS o Launch Services ja impede uma segunda
/// copia e entrega o documento por Apple Event (ver `AppDelegate.swift`).
class SingleInstanceChannel {
  SingleInstanceChannel._(this._dir);

  /// Nome do arquivo de trava. Um por usuario, no diretorio de suporte do app.
  static const String _lockFileName = 'desky.instance.lock';
  static const String _portFileName = 'desky.instance.port';

  final Directory _dir;
  RandomAccessFile? _lock;
  ServerSocket? _server;
  StreamSubscription<Socket>? _subscription;
  StreamSubscription<String>? _lines;
  final StreamController<String> _incoming = StreamController<String>.broadcast();

  /// Mensagens recebidas de outras instancias.
  Stream<String> get incoming => _incoming.stream;

  bool get isPrimary => _lock != null;

  /// Diretorio de trabalho do canal. Em teste pode ser injetado.
  static Directory defaultDirectory() {
    final base = Platform.environment['APPDATA'] ??
        Platform.environment['XDG_CONFIG_HOME'] ??
        Platform.environment['HOME'] ??
        Directory.systemTemp.path;
    return Directory('$base${Platform.pathSeparator}Desky');
  }

  /// Tenta virar a instancia primaria.
  ///
  /// Retorna `null` quando **outra** instancia ja esta aberta; nesse caso o
  /// chamador deve usar [forwardToRunningInstance] e encerrar.
  static Future<SingleInstanceChannel?> acquire({Directory? directory}) async {
    final dir = directory ?? defaultDirectory();
    try {
      await dir.create(recursive: true);
    } catch (_) {
      return null;
    }

    final channel = SingleInstanceChannel._(dir);
    final lockFile = File('${dir.path}${Platform.pathSeparator}$_lockFileName');
    try {
      final handle = await lockFile.open(mode: FileMode.write);
      // Trava exclusiva: falha se outra instancia ja a detem.
      await handle.lock(FileLock.exclusive);
      channel._lock = handle;
    } catch (_) {
      try {
        await lockFile.open(mode: FileMode.write).then((f) => f.close());
      } catch (_) {}
      return null;
    }

    try {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      channel._server = server;
      final portFile = File('${dir.path}${Platform.pathSeparator}$_portFileName');
      await portFile.writeAsString(server.port.toString(), flush: true);
      channel._subscription = server.listen(channel._onSocket);
    } catch (_) {
      await channel.dispose();
      return null;
    }
    return channel;
  }

  /// Le a porta publicada e envia [payload] para a instancia aberta.
  ///
  /// Retorna `false` quando nao foi possivel entregar (instancia morta, porta
  /// expirada ou timeout), para o chamador decidir abrir como primaria.
  static Future<bool> forwardToRunningInstance(String payload, {Directory? directory}) async {
    final dir = directory ?? defaultDirectory();
    final portFile = File('${dir.path}${Platform.pathSeparator}$_portFileName');
    try {
      if (!await portFile.exists()) return false;
      final raw = (await portFile.readAsString()).trim();
      final port = int.tryParse(raw);
      if (port == null || port <= 0 || port > 65535) return false;

      final socket = await Socket.connect(InternetAddress.loopbackIPv4, port,
          timeout: const Duration(seconds: 3));
      socket.writeln(payload);
      await socket.flush();
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onSocket(Socket socket) {
    _lines = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        final payload = line.trim();
        if (payload.isNotEmpty && !_incoming.isClosed) _incoming.add(payload);
      },
      onError: (Object _) {},
      cancelOnError: false,
    );
    socket.done.catchError((Object _) => socket);
  }

  Future<void> dispose() async {
    await _lines?.cancel();
    _lines = null;
    await _subscription?.cancel();
    _subscription = null;
    await _server?.close();
    _server = null;
    try {
      final portFile = File('${_dir.path}${Platform.pathSeparator}$_portFileName');
      if (await portFile.exists()) await portFile.delete();
    } catch (_) {}
    try {
      await _lock?.unlock();
      await _lock?.close();
    } catch (_) {}
    _lock = null;
    if (!_incoming.isClosed) await _incoming.close();
  }

  /// Conveniencia: cria o canal e encaminha o argumento quando ja existe
  /// instancia aberta.
  ///
  /// Retorna o canal primario, ou `null` quando o processo deve encerrar
  /// porque a abertura foi encaminhada com sucesso.
  static Future<SingleInstanceChannel?> startOrForward(String payload) async {
    if (!Platform.isWindows && !Platform.isLinux) {
      // macOS: o Launch Services impede a segunda instancia.
      return SingleInstanceChannel._(defaultDirectory()).._lock = null;
    }
    var channel = await acquire();
    if (channel != null) return channel;

    final forwarded = await forwardToRunningInstance(payload);
    if (forwarded) {
      debugPrint('[single-instance] arquivo encaminhado para a instancia aberta');
      return null;
    }
    // A trava existia mas ninguem atendeu: provavel instancia morta. Tenta de
    // novo como primaria para nao deixar o usuario sem app.
    channel = await acquire();
    return channel;
  }
}