import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../cdn/cdn_resolver.dart';
import '../config/env_config.dart';
import '../constants/app_constants.dart';
import '../localization/app_translation.dart';
import '../../data/models/user_model.dart';
import '../../features/timer/timer_notifier.dart';

final DynamicLibrary? _kernel32 = !kIsWeb && Platform.isWindows
    ? DynamicLibrary.open('kernel32.dll')
    : null;

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

final _CreateFileDart? _createFile = _kernel32
    ?.lookupFunction<_CreateFileC, _CreateFileDart>('CreateFileW');

final _WriteFileDart? _writeFile = _kernel32
    ?.lookupFunction<_WriteFileC, _WriteFileDart>('WriteFile');

final _ReadFileDart? _readFile = _kernel32
    ?.lookupFunction<_ReadFileC, _ReadFileDart>('ReadFile');

final _PeekNamedPipeDart? _peekNamedPipe = _kernel32
    ?.lookupFunction<_PeekNamedPipeC, _PeekNamedPipeDart>('PeekNamedPipe');

final _CloseHandleDart? _closeHandle = _kernel32
    ?.lookupFunction<_CloseHandleC, _CloseHandleDart>('CloseHandle');

class _DiscordPacket {
  final int opcode;
  final String body;
  const _DiscordPacket(this.opcode, this.body);
}

abstract class _DiscordIpcConnection {
  Future<bool> writePacket(int opcode, String jsonString);
  Future<_DiscordPacket?> readPacket({Duration timeout = const Duration(seconds: 3)});

  /// Discards the replies Discord sends for every command. Left unread they
  /// pile up in the pipe until Discord stalls or drops the connection.
  /// Returns false when the connection is gone.
  Future<bool> drain();
  void close();
}

class _WindowsNamedPipeConnection implements _DiscordIpcConnection {
  final int handle;
  _WindowsNamedPipeConnection(this.handle);

  @override
  Future<bool> writePacket(int opcode, String jsonString) async {
    if (_writeFile == null || handle == 0 || handle == -1) return false;
    try {
      final payloadBytes = utf8.encode(jsonString);
      final buffer = Uint8List(8 + payloadBytes.length);
      final byteData = ByteData.sublistView(buffer);
      byteData.setUint32(0, opcode, Endian.little);
      byteData.setUint32(4, payloadBytes.length, Endian.little);
      buffer.setRange(8, 8 + payloadBytes.length, payloadBytes);

      final pBuffer = calloc<Uint8>(buffer.length);
      final pWritten = calloc<Uint32>();
      try {
        pBuffer.asTypedList(buffer.length).setAll(0, buffer);
        final result = _writeFile!(handle, pBuffer, buffer.length, pWritten, nullptr);
        return result != 0;
      } finally {
        calloc.free(pBuffer);
        calloc.free(pWritten);
      }
    } catch (_) {
      return false;
    }
  }

  @override
  Future<_DiscordPacket?> readPacket({Duration timeout = const Duration(seconds: 3)}) async {
    if (_readFile == null || _peekNamedPipe == null || handle == 0 || handle == -1) return null;
    final headerStopwatch = Stopwatch()..start();
    final pTotalAvail = calloc<Uint32>();

    try {
      while (headerStopwatch.elapsed < timeout) {
        final peekRes = _peekNamedPipe!(handle, nullptr, 0, nullptr, pTotalAvail, nullptr);
        if (peekRes != 0 && pTotalAvail.value >= 8) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 20));
      }

      if (pTotalAvail.value < 8) return null;

      final headerBuffer = calloc<Uint8>(8);
      final pBytesRead = calloc<Uint32>();
      try {
        final res = _readFile!(handle, headerBuffer, 8, pBytesRead, nullptr);
        if (res == 0 || pBytesRead.value < 8) return null;
        final headerData = ByteData.sublistView(headerBuffer.asTypedList(8));
        final opcode = headerData.getUint32(0, Endian.little);
        final length = headerData.getUint32(4, Endian.little);

        if (length == 0) return _DiscordPacket(opcode, '');

        final bodyStopwatch = Stopwatch()..start();
        while (bodyStopwatch.elapsed < timeout) {
          _peekNamedPipe!(handle, nullptr, 0, nullptr, pTotalAvail, nullptr);
          if (pTotalAvail.value >= length) break;
          await Future.delayed(const Duration(milliseconds: 20));
        }

        if (pTotalAvail.value < length) return null;

        final bodyBuffer = calloc<Uint8>(length);
        try {
          final bodyRes = _readFile!(handle, bodyBuffer, length, pBytesRead, nullptr);
          if (bodyRes == 0 || pBytesRead.value < length) return null;
          final bodyString = utf8.decode(bodyBuffer.asTypedList(length));
          return _DiscordPacket(opcode, bodyString);
        } finally {
          calloc.free(bodyBuffer);
        }
      } finally {
        calloc.free(headerBuffer);
        calloc.free(pBytesRead);
      }
    } catch (_) {
      return null;
    } finally {
      calloc.free(pTotalAvail);
    }
  }

  @override
  Future<bool> drain() async {
    if (_peekNamedPipe == null || handle == 0 || handle == -1) return false;
    final pTotalAvail = calloc<Uint32>();
    try {
      for (var i = 0; i < 32; i++) {
        final ok = _peekNamedPipe!(handle, nullptr, 0, nullptr, pTotalAvail, nullptr);
        if (ok == 0) return false; // broken pipe: Discord closed it
        if (pTotalAvail.value < 8) return true;
        final packet = await readPacket(timeout: const Duration(seconds: 1));
        if (packet == null) return true;
        if (packet.opcode == 2) return false; // CLOSE
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      calloc.free(pTotalAvail);
    }
  }

  @override
  void close() {
    if (_closeHandle != null && handle != 0 && handle != -1) {
      try {
        _closeHandle!(handle);
      } catch (_) {}
    }
  }
}

class _UnixSocketConnection implements _DiscordIpcConnection {
  final Socket socket;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  bool _closed = false;
  Completer<void>? _dataSignal;

  _UnixSocketConnection(this.socket) {
    socket.listen(
      (data) {
        _buffer.add(data);
        _dataSignal?.complete();
        _dataSignal = null;
      },
      onError: (_) => _markClosed(),
      onDone: _markClosed,
      cancelOnError: true,
    );
  }

  bool get isClosed => _closed;

  void _markClosed() {
    _closed = true;
    _dataSignal?.complete();
    _dataSignal = null;
  }

  @override
  Future<bool> writePacket(int opcode, String jsonString) async {
    if (_closed) return false;
    try {
      final payloadBytes = utf8.encode(jsonString);
      final header = Uint8List(8);
      final byteData = ByteData.sublistView(header);
      byteData.setUint32(0, opcode, Endian.little);
      byteData.setUint32(4, payloadBytes.length, Endian.little);
      socket.add(header);
      socket.add(payloadBytes);
      await socket.flush();
      return true;
    } catch (_) {
      _markClosed();
      return false;
    }
  }

  _DiscordPacket? _takePacket() {
    if (_buffer.length < 8) return null;
    final bytes = _buffer.toBytes();
    final byteData = ByteData.sublistView(bytes);
    final opcode = byteData.getUint32(0, Endian.little);
    final length = byteData.getUint32(4, Endian.little);
    if (bytes.length < 8 + length) return null;
    final body = utf8.decode(bytes.sublist(8, 8 + length), allowMalformed: true);
    _buffer.clear();
    if (bytes.length > 8 + length) _buffer.add(bytes.sublist(8 + length));
    return _DiscordPacket(opcode, body);
  }

  @override
  Future<_DiscordPacket?> readPacket({Duration timeout = const Duration(seconds: 3)}) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final packet = _takePacket();
      if (packet != null) return packet;
      if (_closed) return null;
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return null;
      final signal = _dataSignal ??= Completer<void>();
      try {
        await signal.future.timeout(remaining);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<bool> drain() async {
    while (true) {
      final packet = _takePacket();
      if (packet == null) break;
      if (packet.opcode == 2) return false; // CLOSE
    }
    return !_closed;
  }

  @override
  void close() {
    _closed = true;
    try {
      socket.destroy();
    } catch (_) {}
  }
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
  /// Discord accepts about 5 SET_ACTIVITY calls per 20 s and silently drops
  /// the rest. Updates are spaced by at least this much; clears are not.
  static const Duration minUpdateInterval = Duration(seconds: 5);

  final String _clientId;
  _DiscordIpcConnection? _connection;
  bool _connected = false;
  DiscordPresencePayload? _lastPayload;
  int _nonceCounter = 0;

  /// What the presence should look like (null = nothing). The coordinator
  /// sets it; [_flush] makes Discord match it, one operation at a time.
  DiscordPresencePayload? _desired;
  bool _desiredSet = false;
  DateTime? _lastSentAt;
  Timer? _flushTimer;
  Future<void> _queue = Future.value();
  bool _disposed = false;

  bool get isConnected => _connected;

  DiscordRpcService({String? clientId})
      : _clientId = clientId ?? EnvConfig.discordClientId;

  static String formatStudyDuration(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  /// Image Discord can actually fetch for the user's avatar/studicon.
  ///
  /// Users without a bought studicon (id <= 0) have no CDN image: the app
  /// draws them from bundled assets, and `/sc.v2/-1/...` does not exist, which
  /// is why Discord showed a broken image. Those use the same bundled PNGs,
  /// served from the repository.
  static String presenceImageUrl({
    required UserModel? user,
    required int studiconId,
    required bool isStudying,
    required bool isPaused,
    required int studyMs,
    required int dailyGoalMs,
  }) {
    final hasCustomAvatar = user?.hasCustomAvatar ?? false;
    if (!hasCustomAvatar && studiconId <= 0) {
      final pose = CdnResolver.resolvePose(
        isStudying: isStudying,
        isPaused: isPaused,
        studyMs: studyMs,
        dailyGoalMs: dailyGoalMs,
      );
      final asset = CdnResolver.defaultStudiconAsset(pose, isStudying: isStudying);
      return '${AppConstants.repoRawBaseUrl}/$asset';
    }
    return CdnResolver.userAvatarUrl(
      userId: user?.id ?? 0,
      hasCustomAvatar: hasCustomAvatar,
      studiconId: studiconId,
      isStudying: isStudying,
      isPaused: isPaused,
      studyMs: studyMs,
      dailyGoalMs: dailyGoalMs,
    );
  }

  static DiscordPresencePayload? buildPayload({
    required TimerState timerState,
    required UserModel? user,
    required AppTranslation translation,
    DateTime? now,
  }) {
    final isRunning = timerState.isRunning;
    final isPaused = timerState.isPaused;
    if (!isRunning && !isPaused) return null;

    final studyMs = timerState.todayTotalMs;
    final userStudicon = user?.studiconId ?? 0;
    final studiconId = userStudicon > 0
        ? userStudicon
        : (timerState.studiconId > 0 ? timerState.studiconId : -1);
    final dailyGoalMs = timerState.dailyGoalMinutes * 60 * 1000;

    final imageUrl = presenceImageUrl(
      user: user,
      studiconId: studiconId,
      isStudying: true,
      isPaused: isPaused,
      studyMs: studyMs,
      dailyGoalMs: dailyGoalMs,
    );

    final totalTimeLabel = translation.tr('today_study_time', fallback: 'Tempo Total');
    // The "Playing ..." header is the name of the Discord application behind
    // EnvConfig.discordClientId; the texts we control say YPT.
    final largeImageTooltip =
        '${AppConstants.discordDisplayName} · $totalTimeLabel: ${formatStudyDuration(studyMs)}';

    final statusLabel = isRunning
        ? translation.tr('discord_studying', fallback: 'Estudando')
        : translation.tr('discord_paused', fallback: 'Em pausa');
    final subjectTitle = timerState.currentSubject?.title;
    final detailsText =
        subjectTitle != null && subjectTitle.isNotEmpty ? subjectTitle : statusLabel;

    DateTime? startTime;
    if (isRunning) {
      // Whole seconds: the elapsed time is re-read every tick, and a start
      // that wobbles by a few ms made every tick look like a new presence.
      final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
      final startMs = nowMs - timerState.sessionElapsedMs;
      startTime = DateTime.fromMillisecondsSinceEpoch(startMs - startMs % 1000);
    }

    return DiscordPresencePayload(
      details: detailsText,
      state: statusLabel,
      largeImage: imageUrl,
      largeText: largeImageTooltip,
      smallImage: AppConstants.deskyIconUrl,
      smallText: AppConstants.discordDisplayName,
      buttonLabel: AppConstants.discordDisplayName,
      buttonUrl: 'https://desky.app',
      startTime: startTime,
    );
  }

  /// Same presence for Discord's purposes: the start time may drift by a
  /// couple of seconds (timer re-sync) without being worth an update.
  static bool isEquivalent(DiscordPresencePayload? a, DiscordPresencePayload? b) {
    if (a == null || b == null) return a == b;
    if (a.details != b.details ||
        a.state != b.state ||
        a.largeImage != b.largeImage ||
        a.largeText != b.largeText ||
        a.smallImage != b.smallImage ||
        a.smallText != b.smallText ||
        a.buttonLabel != b.buttonLabel ||
        a.buttonUrl != b.buttonUrl) {
      return false;
    }
    if ((a.startTime == null) != (b.startTime == null)) return false;
    if (a.startTime != null &&
        a.startTime!.difference(b.startTime!).inSeconds.abs() > 2) {
      return false;
    }
    return true;
  }

  Future<void> initialize() async {
    await _serialized(_connect);
  }

  /// Declares what Discord should show (null clears it). Cheap to call on
  /// every timer tick: duplicates are dropped and updates are rate limited.
  void setPresence(DiscordPresencePayload? payload) {
    if (_disposed) return;
    _desired = payload;
    _desiredSet = true;
    _scheduleFlush();
  }

  /// Turns Rich Presence off completely: clears the activity and closes the
  /// IPC connection, so Discord drops anything still attached to this app.
  Future<void> disconnect() async {
    _desired = null;
    _desiredSet = false;
    _flushTimer?.cancel();
    await _serialized(() async {
      await _sendClear();
      _close(sayGoodbye: true);
    });
  }

  // Kept for callers that used the old API (app exit).
  Future<void> clearPresence() async {
    _desired = null;
    _desiredSet = true;
    _flushTimer?.cancel();
    await _serialized(_flush);
  }

  void _scheduleFlush() {
    if (_flushTimer?.isActive ?? false) return;
    var delay = Duration.zero;
    final last = _lastSentAt;
    final isClear = _desired == null;
    if (!isClear && last != null) {
      final since = DateTime.now().difference(last);
      if (since < minUpdateInterval) delay = minUpdateInterval - since;
    }
    _flushTimer = Timer(delay, () => _serialized(_flush));
  }

  Future<void> _serialized(Future<void> Function() op) {
    final next = _queue.then((_) => op()).catchError((_) {});
    _queue = next;
    return next;
  }

  Future<void> _flush() async {
    if (_disposed || !_desiredSet) return;
    final desired = _desired;

    if (desired == null) {
      await _sendClear();
      return;
    }
    if (_connected && isEquivalent(_lastPayload, desired)) return;

    final last = _lastSentAt;
    if (last != null && DateTime.now().difference(last) < minUpdateInterval) {
      _scheduleFlush();
      return;
    }
    await _sendActivity(desired);
    // The desired state may have changed while we were sending.
    if (!identical(_desired, desired)) _scheduleFlush();
  }

  Future<void> _connect() async {
    if (_connected && _connection != null) return;
    if (_disposed || kIsWeb || _clientId.isEmpty) return;
    _close();

    try {
      if (Platform.isWindows && _createFile != null) {
        const genericReadWrite = 0xC0000000;
        const openExisting = 3;

        for (int i = 0; i < 10; i++) {
          final pipeName = r'\\.\pipe\discord-ipc-' + i.toString();
          final nativeName = pipeName.toNativeUtf16();
          try {
            final handle = _createFile!(
              nativeName,
              genericReadWrite,
              0,
              nullptr,
              openExisting,
              0,
              0,
            );
            if (handle != 0 && handle != -1) {
              _connection = _WindowsNamedPipeConnection(handle);
              break;
            }
          } finally {
            calloc.free(nativeName);
          }
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        final tempDir = Platform.environment['XDG_RUNTIME_DIR'] ??
            Platform.environment['TMPDIR'] ??
            Platform.environment['TMP'] ??
            Platform.environment['TEMP'] ??
            '/tmp';

        for (int i = 0; i < 10; i++) {
          try {
            final socketPath = '$tempDir/discord-ipc-$i';
            final socket = await Socket.connect(
              InternetAddress(socketPath, type: InternetAddressType.unix),
              0,
              timeout: const Duration(milliseconds: 300),
            );
            _connection = _UnixSocketConnection(socket);
            break;
          } catch (_) {}
        }
      }

      final connection = _connection;
      if (connection == null) return;

      final ok = await connection.writePacket(0, jsonEncode({'v': 1, 'client_id': _clientId}));
      final resp = ok ? await connection.readPacket(timeout: const Duration(seconds: 5)) : null;
      // opcode 1 = FRAME carrying the READY dispatch.
      if (resp != null && resp.opcode == 1) {
        _connected = true;
      } else {
        _close();
      }
    } catch (_) {
      _close();
    }
  }

  Future<bool> _sendCommand(Map<String, dynamic> args) async {
    _nonceCounter++;
    final packet = jsonEncode({
      'cmd': 'SET_ACTIVITY',
      'args': args,
      'nonce': _nonceCounter.toString(),
    });
    final connection = _connection;
    if (connection == null) return false;
    final ok = await connection.writePacket(1, packet) && await connection.drain();
    if (!ok) _close();
    return ok;
  }

  Future<void> _sendActivity(DiscordPresencePayload payload) async {
    try {
      if (!_connected) await _connect();
      if (!_connected) return;

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
        'type': 0,
        'details': payload.details,
        'assets': assets,
      };
      if (payload.state != null && payload.state!.isNotEmpty) {
        activity['state'] = payload.state;
      }
      if (payload.startTime != null) {
        activity['timestamps'] = {'start': payload.startTime!.millisecondsSinceEpoch};
      }
      if (payload.buttonLabel != null && payload.buttonUrl != null) {
        activity['buttons'] = [
          {'label': payload.buttonLabel!, 'url': payload.buttonUrl!},
        ];
      }

      _lastSentAt = DateTime.now();
      if (await _sendCommand({'pid': pid, 'activity': activity})) {
        _lastPayload = payload;
      } else {
        _lastPayload = null;
      }
    } catch (_) {
      _close();
    }
  }

  Future<void> _sendClear() async {
    _lastPayload = null;
    if (!_connected || _connection == null) return;
    try {
      // Not rate limited on purpose: stopping must clear Discord right away.
      final ok = await _sendCommand({'pid': pid, 'activity': null});
      if (!ok) {
        // Could not clear: closing the connection makes Discord drop the
        // activity of this client anyway, so the timer never lingers there.
        _close();
      }
    } catch (_) {
      _close();
    }
  }

  void _close({bool sayGoodbye = false}) {
    final connection = _connection;
    _connection = null;
    _connected = false;
    _lastPayload = null;
    if (connection == null) return;
    try {
      if (sayGoodbye) connection.writePacket(2, '{}');
    } catch (_) {}
    connection.close();
  }

  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _close(sayGoodbye: true);
  }
}

final discordRpcServiceProvider = Provider<DiscordRpcService>((ref) {
  final service = DiscordRpcService();
  ref.onDispose(() => service.dispose());
  return service;
});
