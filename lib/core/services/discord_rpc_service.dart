import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
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
  _UnixSocketConnection(this.socket);

  @override
  Future<bool> writePacket(int opcode, String jsonString) async {
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
      return false;
    }
  }

  @override
  Future<_DiscordPacket?> readPacket({Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final data = await socket.first.timeout(timeout);
      if (data.length < 8) return null;
      final byteData = ByteData.sublistView(Uint8List.fromList(data));
      final opcode = byteData.getUint32(0, Endian.little);
      final length = byteData.getUint32(4, Endian.little);
      final body = utf8.decode(data.sublist(8, 8 + length));
      return _DiscordPacket(opcode, body);
    } catch (_) {
      return null;
    }
  }

  @override
  void close() {
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
  final String _clientId;
  _DiscordIpcConnection? _connection;
  bool _connected = false;
  DiscordPresencePayload? _lastPayload;
  int _nonceCounter = 0;

  bool get isConnected => _connected;

  DiscordRpcService({String? clientId})
      : _clientId = clientId ?? EnvConfig.discordClientId;

  static String formatStudyDuration(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m';
  }

  static DiscordPresencePayload buildPayload({
    required TimerState timerState,
    required UserModel? user,
    required AppTranslation translation,
  }) {
    final isRunning = timerState.isRunning;
    final isPaused = timerState.isPaused;
    final isStudying = isRunning || isPaused;
    final studyMs = timerState.todayTotalMs;
    final studiconId = user?.studiconId ?? (timerState.studiconId > 0 ? timerState.studiconId : -1);
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
    final totalTimeLabel = translation.tr('today_study_time', fallback: 'Tempo Total');
    final largeImageTooltip = '$totalTimeLabel: $totalTimeFormatted';

    String detailsText;
    DateTime? startTime;

    if (isRunning) {
      final studyingLabel = translation.tr('discord_studying', fallback: 'Estudando');
      final subjectTitle = timerState.currentSubject?.title;
      detailsText = subjectTitle != null && subjectTitle.isNotEmpty
          ? '$studyingLabel: $subjectTitle'
          : studyingLabel;
      startTime = timerState.sessionStartAt ?? DateTime.now();
    } else if (isPaused) {
      final pausedLabel = translation.tr('discord_paused', fallback: 'Em pausa');
      final subjectTitle = timerState.currentSubject?.title;
      detailsText = subjectTitle != null && subjectTitle.isNotEmpty
          ? '$pausedLabel: $subjectTitle'
          : pausedLabel;
      startTime = null;
    } else {
      detailsText = translation.tr('discord_idle', fallback: 'No Desky');
      startTime = null;
    }

    return DiscordPresencePayload(
      details: detailsText,
      state: null,
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

  Future<void> connect() async {
    if (_connected && _connection != null) return;
    if (kIsWeb) return;

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

      if (_connection != null) {
        final handshakePayload = jsonEncode({
          'v': 1,
          'client_id': _clientId,
        });
        final ok = await _connection!.writePacket(0, handshakePayload);
        if (ok) {
          final resp = await _connection!.readPacket(timeout: const Duration(seconds: 5));
          if (resp != null && resp.opcode == 1) {
            _connected = true;
          } else {
            _connected = false;
            _connection?.close();
            _connection = null;
          }
        } else {
          _connected = false;
          _connection?.close();
          _connection = null;
        }
      } else {
        _connected = false;
      }
    } catch (_) {
      _connected = false;
      _connection?.close();
      _connection = null;
    }
  }

  Future<void> updatePresence(DiscordPresencePayload payload) async {
    if (_lastPayload == payload && _connected) return;

    try {
      if (!_connected || _connection == null) {
        await connect();
      }
      if (!_connected || _connection == null) return;

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
          'start': (payload.startTime!.millisecondsSinceEpoch / 1000).round(),
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

      _nonceCounter++;
      final packetPayload = jsonEncode({
        'cmd': 'SET_ACTIVITY',
        'args': {
          'pid': pid,
          'activity': activity,
        },
        'nonce': _nonceCounter.toString(),
      });

      final success = await _connection!.writePacket(1, packetPayload);
      if (success) {
        _lastPayload = payload;
      } else {
        _connected = false;
        _connection?.close();
        _connection = null;
      }
    } catch (_) {
      _connected = false;
      _connection?.close();
      _connection = null;
    }
  }

  Future<void> clearPresence() async {
    _lastPayload = null;
    if (!_connected || _connection == null) return;
    try {
      _nonceCounter++;
      final packetPayload = jsonEncode({
        'cmd': 'SET_ACTIVITY',
        'args': {
          'pid': pid,
          'activity': null,
        },
        'nonce': _nonceCounter.toString(),
      });
      await _connection!.writePacket(1, packetPayload);
    } catch (_) {
      _connected = false;
    }
  }

  void dispose() {
    try {
      if (_connected && _connection != null) {
        _connection!.writePacket(2, '{}');
      }
      _connection?.close();
    } catch (_) {}
    _connection = null;
    _connected = false;
    _lastPayload = null;
  }
}

final discordRpcServiceProvider = Provider<DiscordRpcService>((ref) {
  final service = DiscordRpcService();
  ref.onDispose(() => service.dispose());
  return service;
});
