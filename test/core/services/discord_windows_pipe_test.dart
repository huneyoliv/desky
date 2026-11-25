import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:desky/core/services/discord_ipc_protocol.dart';
import 'package:desky/core/services/discord_rpc_service.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _CreateNamedPipeC = IntPtr Function(
  Pointer<Utf16>,
  Uint32,
  Uint32,
  Uint32,
  Uint32,
  Uint32,
  Uint32,
  Pointer<Void>,
);
typedef _CreateNamedPipeDart = int Function(
  Pointer<Utf16>,
  int,
  int,
  int,
  int,
  int,
  int,
  Pointer<Void>,
);
typedef _ConnectNamedPipeC = Int32 Function(IntPtr, Pointer<Void>);
typedef _ConnectNamedPipeDart = int Function(int, Pointer<Void>);
typedef _DisconnectNamedPipeC = Int32 Function(IntPtr);
typedef _DisconnectNamedPipeDart = int Function(int);
typedef _CloseHandleC = Int32 Function(IntPtr);
typedef _CloseHandleDart = int Function(int);
typedef _GetLastErrorDart = int Function();
typedef _WriteFileC = Int32 Function(
  IntPtr,
  Pointer<Uint8>,
  Uint32,
  Pointer<Uint32>,
  Pointer<Void>,
);
typedef _WriteFileDart = int Function(
  int,
  Pointer<Uint8>,
  int,
  Pointer<Uint32>,
  Pointer<Void>,
);
typedef _ReadFileC = Int32 Function(
  IntPtr,
  Pointer<Uint8>,
  Uint32,
  Pointer<Uint32>,
  Pointer<Void>,
);
typedef _ReadFileDart = int Function(
  int,
  Pointer<Uint8>,
  int,
  Pointer<Uint32>,
  Pointer<Void>,
);

/// Loaded lazily so non-Windows test runners never open kernel32.dll.
class _Native {
  static final DynamicLibrary _lib = DynamicLibrary.open('kernel32.dll');
  static final createNamedPipe =
      _lib.lookupFunction<_CreateNamedPipeC, _CreateNamedPipeDart>(
    'CreateNamedPipeW',
  );
  static final connectNamedPipe =
      _lib.lookupFunction<_ConnectNamedPipeC, _ConnectNamedPipeDart>(
    'ConnectNamedPipe',
  );
  static final disconnectNamedPipe =
      _lib.lookupFunction<_DisconnectNamedPipeC, _DisconnectNamedPipeDart>(
    'DisconnectNamedPipe',
  );
  static final closeHandle =
      _lib.lookupFunction<_CloseHandleC, _CloseHandleDart>('CloseHandle');
  static final getLastError =
      _lib.lookupFunction<Uint32 Function(), _GetLastErrorDart>('GetLastError');
  static final writeFile =
      _lib.lookupFunction<_WriteFileC, _WriteFileDart>('WriteFile');
  static final readFile =
      _lib.lookupFunction<_ReadFileC, _ReadFileDart>('ReadFile');
}

int _createServer() {
  for (var index = 9; index >= 0; index--) {
    final path = (r'\\.\pipe\discord-ipc-' + index.toString()).toNativeUtf16();
    try {
      final handle = _Native.createNamedPipe(
        path,
        3, // PIPE_ACCESS_DUPLEX
        0, // PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT
        1,
        4096,
        4096,
        0,
        nullptr,
      );
      if (handle != 0 && handle != -1) return handle;
      stderr.writeln(
          'CreateNamedPipeW failed for index $index: handle=$handle error=${_Native.getLastError()}');
    } finally {
      calloc.free(path);
    }
  }
  return -1;
}

Uint8List _readExact(int handle, int count) {
  final buffer = calloc<Uint8>(count);
  final read = calloc<Uint32>();
  final builder = BytesBuilder(copy: false);
  try {
    var offset = 0;
    while (offset < count) {
      final ok =
          _Native.readFile(handle, buffer, count - offset, read, nullptr);
      if (ok == 0 || read.value == 0) {
        throw StateError('Named pipe closed while reading');
      }
      builder.add(buffer.asTypedList(read.value));
      offset += read.value;
    }
    return builder.takeBytes();
  } finally {
    calloc.free(buffer);
    calloc.free(read);
  }
}

void _writeAll(int handle, List<int> bytes) {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final buffer = calloc<Uint8>(data.length);
  final written = calloc<Uint32>();
  try {
    buffer.asTypedList(data.length).setAll(0, data);
    final ok = _Native.writeFile(handle, buffer, data.length, written, nullptr);
    if (ok == 0 || written.value != data.length) {
      throw StateError('Named pipe write failed');
    }
  } finally {
    calloc.free(buffer);
    calloc.free(written);
  }
}

Uint8List _readFrame(int handle) {
  final header = _readExact(handle, 8);
  final length = ByteData.sublistView(header).getUint32(4, Endian.little);
  if (length > DiscordIpcLimits.maxFrameBytes) {
    throw StateError('Oversized test frame');
  }
  return _readExact(handle, length);
}

void _serve(int handle) {
  try {
    if (_Native.connectNamedPipe(handle, nullptr) == 0) {
      throw StateError('ConnectNamedPipe failed');
    }
    stderr.writeln('SERVER: client connected');
    final handshake =
        jsonDecode(utf8.decode(_readFrame(handle))) as Map<String, dynamic>;
    if (handshake['v'] != 1 || handshake['client_id'] != '123') {
      throw StateError('Unexpected handshake');
    }
    stderr.writeln('SERVER: handshake read');

    final ready = encodeDiscordIpcFrame(
      DiscordIpcOpcode.frame,
      jsonEncode({
        'cmd': 'DISPATCH',
        'evt': 'READY',
        'data': {
          'v': 1,
          'user': {'id': '1'}
        },
      }),
    );
    _writeAll(handle, ready.sublist(0, 3));
    _writeAll(handle, ready.sublist(3, 11));
    _writeAll(handle, ready.sublist(11));
    stderr.writeln('SERVER: READY sent');

    final activity =
        jsonDecode(utf8.decode(_readFrame(handle))) as Map<String, dynamic>;
    if (activity['cmd'] != 'SET_ACTIVITY') {
      throw StateError('Expected SET_ACTIVITY');
    }
    final details = (activity['args'] as Map<String, dynamic>)['activity']
        as Map<String, dynamic>;
    if (details['details'] != 'native-pipe-test') {
      throw StateError('Unexpected activity payload');
    }
  } finally {
    _Native.disconnectNamedPipe(handle);
    _Native.closeHandle(handle);
  }
}

void main() {
  test(
    'native named pipe carries fragmented READY and SET_ACTIVITY',
    () async {
      final handle = _createServer();
      expect(handle, isNot(-1), reason: 'No discord-ipc-N endpoint available');

      var serverDone = false;
      final server = Isolate.run(() => _serve(handle))
          .whenComplete(() => serverDone = true);
      server.catchError((Object error) {
        stderr.writeln('SERVER_ERROR: $error');
      });
      final service = DiscordRpcService(
        clientId: '123',
        handshakeTimeout: const Duration(seconds: 5),
      );
      try {
        await service.connect().timeout(const Duration(seconds: 10));
        expect(service.isConnected, isTrue);
        await service
            .updatePresence(
              const DiscordPresencePayload(
                details: 'native-pipe-test',
                largeImage: 'https://example.invalid/icon.png',
                largeText: 'Today: 00h 01m',
              ),
            )
            .timeout(const Duration(seconds: 10));
        await server.timeout(const Duration(seconds: 10));
      } finally {
        service.dispose();
        if (!serverDone) {
          _Native.closeHandle(handle);
          await server.catchError((_) {});
        }
      }
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
