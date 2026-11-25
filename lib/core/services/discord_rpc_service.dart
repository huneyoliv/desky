import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cdn/cdn_resolver.dart';
import '../config/env_config.dart';
import '../constants/app_constants.dart';
import 'discord_ipc_protocol.dart';
import '../localization/app_translation.dart';
import '../../data/models/user_model.dart';
import '../../features/timer/timer_notifier.dart';

final DynamicLibrary? _kernel32 =
    !kIsWeb && Platform.isWindows ? DynamicLibrary.open('kernel32.dll') : null;

typedef _CreateFileC = IntPtr Function(
    Pointer<Utf16> lpFileName,
    Uint32 dwDesiredAccess,
    Uint32 dwShareMode,
    Pointer<Void> lpSecurityAttributes,
    Uint32 dwCreationDisposition,
    Uint32 dwFlagsAndAttributes,
    IntPtr hTemplateFile);

typedef _CreateFileDart = int Function(
    Pointer<Utf16> lpFileName,
    int dwDesiredAccess,
    int dwShareMode,
    Pointer<Void> lpSecurityAttributes,
    int dwCreationDisposition,
    int dwFlagsAndAttributes,
    int hTemplateFile);

typedef _WriteFileC = Int32 Function(
    IntPtr hFile,
    Pointer<Uint8> lpBuffer,
    Uint32 nNumberOfBytesToWrite,
    Pointer<Uint32> lpNumberOfBytesWritten,
    Pointer<Void> lpOverlapped);

typedef _WriteFileDart = int Function(
    int hFile,
    Pointer<Uint8> lpBuffer,
    int nNumberOfBytesToWrite,
    Pointer<Uint32> lpNumberOfBytesWritten,
    Pointer<Void> lpOverlapped);

typedef _ReadFileC = Int32 Function(
    IntPtr hFile,
    Pointer<Uint8> lpBuffer,
    Uint32 nNumberOfBytesToRead,
    Pointer<Uint32> lpNumberOfBytesRead,
    Pointer<Void> lpOverlapped);

typedef _ReadFileDart = int Function(
    int hFile,
    Pointer<Uint8> lpBuffer,
    int nNumberOfBytesToRead,
    Pointer<Uint32> lpNumberOfBytesRead,
    Pointer<Void> lpOverlapped);

typedef _PeekNamedPipeC = Int32 Function(
    IntPtr hNamedPipe,
    Pointer<Void> lpBuffer,
    Uint32 nBufferSize,
    Pointer<Uint32> lpBytesRead,
    Pointer<Uint32> lpTotalBytesAvail,
    Pointer<Uint32> lpBytesLeftThisMessage);

typedef _PeekNamedPipeDart = int Function(
    int hNamedPipe,
    Pointer<Void> lpBuffer,
    int nBufferSize,
    Pointer<Uint32> lpBytesRead,
    Pointer<Uint32> lpTotalBytesAvail,
    Pointer<Uint32> lpBytesLeftThisMessage);

typedef _CloseHandleC = Int32 Function(IntPtr hObject);
typedef _CloseHandleDart = int Function(int hObject);

final _CreateFileDart? _createFile =
    _kernel32?.lookupFunction<_CreateFileC, _CreateFileDart>('CreateFileW');

final _WriteFileDart? _writeFile =
    _kernel32?.lookupFunction<_WriteFileC, _WriteFileDart>('WriteFile');

final _ReadFileDart? _readFile =
    _kernel32?.lookupFunction<_ReadFileC, _ReadFileDart>('ReadFile');

final _PeekNamedPipeDart? _peekNamedPipe = _kernel32
    ?.lookupFunction<_PeekNamedPipeC, _PeekNamedPipeDart>('PeekNamedPipe');

final _CloseHandleDart? _closeHandle =
    _kernel32?.lookupFunction<_CloseHandleC, _CloseHandleDart>('CloseHandle');

/// Named pipe transport (Windows). Reads only what PeekNamedPipe reports as
/// available, in bounded chunks, so a peer that announces a huge frame never
/// makes us allocate for it: the frame decoder rejects the header first.
class _WindowsNamedPipeTransport implements DiscordIpcTransport {
  _WindowsNamedPipeTransport(this.handle);

  final int handle;
  bool _closed = false;

  static const int _chunkBytes = 16 * 1024;

  bool get _usable =>
      !_closed &&
      _writeFile != null &&
      _readFile != null &&
      _peekNamedPipe != null &&
      handle != 0 &&
      handle != -1;

  @override
  Future<bool> write(Uint8List bytes) async {
    if (!_usable) return false;
    final pBuffer = calloc<Uint8>(bytes.length);
    final pWritten = calloc<Uint32>();
    try {
      pBuffer.asTypedList(bytes.length).setAll(0, bytes);
      final ok = _writeFile!(handle, pBuffer, bytes.length, pWritten, nullptr);
      return ok != 0 && pWritten.value == bytes.length;
    } catch (_) {
      return false;
    } finally {
      calloc.free(pBuffer);
      calloc.free(pWritten);
    }
  }

  @override
  Future<Uint8List?> read(Duration wait) async {
    if (!_usable) return null;
    final pAvail = calloc<Uint32>();
    try {
      final stopwatch = Stopwatch()..start();
      while (true) {
        final ok =
            _peekNamedPipe!(handle, nullptr, 0, nullptr, pAvail, nullptr);
        if (ok == 0) return null; // broken pipe: Discord went away
        if (pAvail.value > 0) break;
        if (stopwatch.elapsed >= wait) return Uint8List(0);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final toRead = pAvail.value < _chunkBytes ? pAvail.value : _chunkBytes;
      final pBuffer = calloc<Uint8>(toRead);
      final pRead = calloc<Uint32>();
      try {
        final ok = _readFile!(handle, pBuffer, toRead, pRead, nullptr);
        if (ok == 0) return null;
        return Uint8List.fromList(pBuffer.asTypedList(pRead.value));
      } finally {
        calloc.free(pBuffer);
        calloc.free(pRead);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(pAvail);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_closeHandle != null && handle != 0 && handle != -1) {
      try {
        _closeHandle!(handle);
      } catch (_) {}
    }
  }
}

/// Opens a byte stream to a running Discord client, or returns null.
typedef DiscordIpcConnector = Future<DiscordIpcTransport?> Function();

Future<DiscordIpcTransport?> _connectToDiscord() async {
  if (Platform.isWindows && _createFile != null) {
    const genericReadWrite = 0xC0000000;
    const openExisting = 3;
    for (int i = 0; i < 10; i++) {
      final nativeName =
          (r'\\.\pipe\discord-ipc-' + i.toString()).toNativeUtf16();
      try {
        final handle = _createFile!(
            nativeName, genericReadWrite, 0, nullptr, openExisting, 0, 0);
        if (handle != 0 && handle != -1) {
          return _WindowsNamedPipeTransport(handle);
        }
      } finally {
        calloc.free(nativeName);
      }
    }
    return null;
  }
  if (Platform.isLinux || Platform.isMacOS) {
    final tempDir = Platform.environment['XDG_RUNTIME_DIR'] ??
        Platform.environment['TMPDIR'] ??
        Platform.environment['TMP'] ??
        Platform.environment['TEMP'] ??
        '/tmp';
    for (int i = 0; i < 10; i++) {
      try {
        final socket = await Socket.connect(
          InternetAddress('$tempDir/discord-ipc-$i',
              type: InternetAddressType.unix),
          0,
          timeout: const Duration(milliseconds: 300),
        );
        return DiscordSocketTransport(socket);
      } catch (_) {}
    }
  }
  return null;
}

class DiscordPresencePayload {
  final String details;
  final String? state;
  final String largeImage;
  final String largeText;
  final String? smallImage;
  final String? smallText;
  final DateTime? startTime;
  final String? buttonLabel;
  final String? buttonUrl;

  const DiscordPresencePayload({
    required this.details,
    this.state,
    required this.largeImage,
    required this.largeText,
    this.smallImage,
    this.smallText,
    this.startTime,
    this.buttonLabel,
    this.buttonUrl,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscordPresencePayload &&
        other.details == details &&
        other.state == state &&
        other.largeImage == largeImage &&
        other.largeText == largeText &&
        other.smallImage == smallImage &&
        other.smallText == smallText &&
        other.startTime == startTime &&
        other.buttonLabel == buttonLabel &&
        other.buttonUrl == buttonUrl;
  }

  @override
  int get hashCode => Object.hash(
        details,
        state,
        largeImage,
        largeText,
        smallImage,
        smallText,
        startTime,
        buttonLabel,
        buttonUrl,
      );
}

class DiscordRpcService {
  final String _clientId;
  final DiscordIpcConnector _connector;
  DiscordIpcConnection? _connection;
  Future<void>? _connectFuture;
  bool _connected = false;
  DiscordPresencePayload? _lastPayload;
  DiscordPresencePayload? _pendingPayload;
  Future<void> _commandTail = Future<void>.value();
  bool _presencePending = false;
  bool _disposed = false;
  int _nonceCounter = 0;

  bool get isConnected => _connected;

  /// [connector] is for tests: it replaces the real pipe/socket lookup.
  DiscordRpcService({
    String? clientId,
    DiscordIpcConnector? connector,
    this.handshakeTimeout = const Duration(seconds: 5),
  })  : _clientId = clientId ?? EnvConfig.discordClientId,
        _connector = connector ?? _connectToDiscord;

  /// How long Discord gets to answer the handshake.
  final Duration handshakeTimeout;

  static String formatStudyDuration(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  static DiscordPresencePayload? buildPayload({
    required TimerState timerState,
    required UserModel? user,
    required AppTranslation translation,
  }) {
    final isRunning = timerState.isRunning;
    final isPaused = timerState.isPaused;
    final isStudying = isRunning || isPaused;

    if (!isStudying) {
      return null;
    }

    final studyMs = timerState.todayTotalMs;
    final studiconId = user?.studiconId ??
        (timerState.studiconId > 0 ? timerState.studiconId : -1);
    final hasCustomAvatar = user?.hasCustomAvatar ?? false;
    final userId = user?.id ?? 0;
    final dailyGoalMs = timerState.dailyGoalMinutes * 60 * 1000;

    final avatarUrl = CdnResolver.userAvatarUrl(
      userId: userId,
      hasCustomAvatar: hasCustomAvatar,
      studiconId: studiconId,
      isStudying: isStudying,
      isPaused: isPaused,
      studyMs: studyMs,
      dailyGoalMs: dailyGoalMs,
    );

    final totalTimeFormatted = formatStudyDuration(studyMs);
    final totalTimeLabel =
        translation.tr('today_study_time', fallback: 'Tempo Total');
    final largeImageTooltip = '$totalTimeLabel: $totalTimeFormatted';

    String detailsText;
    String? stateText;
    DateTime? startTime;

    if (isRunning) {
      final studyingLabel =
          translation.tr('discord_studying', fallback: 'Estudando');
      final subjectTitle = timerState.currentSubject?.title;
      detailsText = subjectTitle != null && subjectTitle.isNotEmpty
          ? subjectTitle
          : studyingLabel;
      stateText = studyingLabel;
      final elapsedMs = timerState.sessionElapsedMs;
      startTime = DateTime.now().subtract(Duration(milliseconds: elapsedMs));
    } else if (isPaused) {
      final pausedLabel =
          translation.tr('discord_paused', fallback: 'Em pausa');
      final subjectTitle = timerState.currentSubject?.title;
      detailsText = subjectTitle != null && subjectTitle.isNotEmpty
          ? subjectTitle
          : pausedLabel;
      stateText = pausedLabel;
      startTime = null;
    } else {
      return null;
    }

    return DiscordPresencePayload(
      details: detailsText,
      state: stateText,
      largeImage: avatarUrl,
      largeText: largeImageTooltip,
      smallImage: AppConstants.deskyIconUrl,
      smallText: 'Desky',
      startTime: startTime,
      buttonLabel: 'Desky',
      buttonUrl: 'https://desky.app',
    );
  }

  Future<void> initialize() async {
    await connect();
  }

  Future<void> connect() {
    if (_disposed || kIsWeb || _clientId.isEmpty) return Future<void>.value();
    if (_connected && _connection != null && !_connection!.isClosed) {
      return Future<void>.value();
    }
    final existing = _connectFuture;
    if (existing != null) return existing;

    late final Future<void> attempt;
    attempt = _connectOnce().whenComplete(() {
      if (identical(_connectFuture, attempt)) _connectFuture = null;
    });
    _connectFuture = attempt;
    return attempt;
  }

  Future<void> _connectOnce() async {
    _drop();
    DiscordIpcConnection? connection;
    try {
      final transport = await _connector();
      if (_disposed) {
        transport?.close();
        return;
      }
      if (transport == null) return;
      connection = DiscordIpcConnection(transport);
      // Track the handshake too, so dispose can close its pending read.
      _connection = connection;
      final sent = await connection.writeFrame(
        DiscordIpcOpcode.handshake,
        jsonEncode({'v': 1, 'client_id': _clientId}),
      );
      final reply = sent ? await connection.readFrame(handshakeTimeout) : null;
      // Only a READY dispatch proves a Discord client accepted this app; a
      // CLOSE, an ERROR event or anything malformed is a failed handshake.
      if (!_disposed &&
          identical(_connection, connection) &&
          isDiscordReadyFrame(reply)) {
        _connected = true;
      } else {
        _drop(connection);
      }
    } catch (_) {
      if (connection == null) {
        if (!_disposed) _drop();
      } else {
        _drop(connection);
      }
    }
  }

  /// Sends one command and handles whatever Discord sent back so far.
  Future<bool> _sendCommand(Map<String, dynamic> args) async {
    final connection = _connection;
    if (_disposed) return false;
    if (connection == null || connection.isClosed) {
      if (connection == null) {
        _drop();
      } else {
        _drop(connection);
      }
      return false;
    }
    // Reserve and encode the nonce before the first await. Public commands are
    // serialized below, and this also keeps concurrent callers collision-free.
    final nonce = (++_nonceCounter).toString();
    final payload =
        jsonEncode({'cmd': 'SET_ACTIVITY', 'args': args, 'nonce': nonce});
    final ok = await connection.drain() &&
        await connection.writeFrame(DiscordIpcOpcode.frame, payload) &&
        await connection.drain();
    if (!ok && connection.isClosed) _drop(connection);
    return ok;
  }

  Future<void> _enqueuePresence(DiscordPresencePayload? payload) {
    if (_disposed) return Future<void>.value();
    // One pending value is enough: intermediate states are superseded before
    // they reach the wire, while an in-flight command finishes first.
    _pendingPayload = payload;
    _presencePending = true;
    _commandTail = _commandTail.then((_) => _flushPresence());
    return _commandTail;
  }

  Future<void> _flushPresence() async {
    if (_disposed || !_presencePending) return;
    final payload = _pendingPayload;
    _pendingPayload = null;
    _presencePending = false;
    DiscordIpcConnection? connection;

    try {
      if (payload == null && (!_connected || _connection == null)) {
        _lastPayload = null;
        return;
      }
      if (!_connected || _connection == null || _connection!.isClosed) {
        if (payload == null) {
          _drop();
          return;
        }
        await connect();
      }
      connection = _connection;
      if (_disposed || !_connected || connection == null) return;
      if (payload != null && _lastPayload == payload) return;

      if (payload == null) {
        if (await _sendCommand({'pid': pid, 'activity': null}) &&
            !_disposed &&
            identical(_connection, connection)) {
          _lastPayload = null;
        }
        return;
      }

      final assets = <String, dynamic>{
        'large_image': payload.largeImage,
        'large_text': payload.largeText,
      };

      if (payload.smallImage != null && payload.smallImage!.isNotEmpty) {
        assets['small_image'] = payload.smallImage;
        if (payload.smallText != null && payload.smallText!.isNotEmpty) {
          assets['small_text'] = payload.smallText;
        }
      }

      final activity = <String, dynamic>{
        'details': payload.details,
        'assets': assets,
      };

      if (payload.state != null && payload.state!.isNotEmpty) {
        activity['state'] = payload.state;
      }

      if (payload.startTime != null) {
        activity['timestamps'] = {
          'start': payload.startTime!.millisecondsSinceEpoch,
        };
      }

      if (payload.buttonLabel != null && payload.buttonUrl != null) {
        activity['buttons'] = [
          {
            'label': payload.buttonLabel!,
            'url': payload.buttonUrl!,
          }
        ];
      }

      if (await _sendCommand({'pid': pid, 'activity': activity}) &&
          !_disposed &&
          identical(_connection, connection)) {
        _lastPayload = payload;
      }
    } catch (_) {
      if (connection == null) {
        if (!_disposed) _drop();
      } else {
        _drop(connection);
      }
    }
  }

  Future<void> updatePresence(DiscordPresencePayload payload) =>
      _enqueuePresence(payload);

  Future<void> clearPresence() => _enqueuePresence(null);

  void _drop([DiscordIpcConnection? expected]) {
    final current = _connection;
    if (expected != null && !identical(current, expected)) {
      // An old transport must never tear down its replacement.
      expected.close();
      return;
    }
    (expected ?? current)?.close();
    _connection = null;
    _connected = false;
    _lastPayload = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _presencePending = false;
    _pendingPayload = null;
    final connection = _connection;
    if (_connected && connection != null && !connection.isClosed) {
      // Best effort goodbye; the transport is closed right after.
      unawaited(connection
          .writeFrame(DiscordIpcOpcode.close, '{}')
          .catchError((_) => false));
    }
    _drop();
  }
}

final discordRpcServiceProvider = Provider<DiscordRpcService>((ref) {
  final service = DiscordRpcService();
  ref.onDispose(() => service.dispose());
  return service;
});
