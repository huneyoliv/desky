import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Discord local RPC framing, kept free of platform code so it can be tested
/// against hostile input.
///
/// A frame is an 8-byte little-endian header (opcode, payload length)
/// followed by a UTF-8 JSON payload. Whatever sits on the other end of the
/// pipe or socket is untrusted: any local process can create
/// `discord-ipc-N`. Every limit below is enforced before memory is allocated
/// for a frame.
class DiscordIpcOpcode {
  static const int handshake = 0;
  static const int frame = 1;
  static const int close = 2;
  static const int ping = 3;
  static const int pong = 4;

  static bool isValid(int op) => op >= handshake && op <= pong;
}

/// Limits for one connection.
class DiscordIpcLimits {
  /// Largest payload accepted in a single frame, in either direction.
  /// Discord's own replies are a few KiB; SET_ACTIVITY payloads are well
  /// under 4 KiB.
  static const int maxFrameBytes = 64 * 1024;

  /// Largest amount of unparsed data held for a connection. A peer that sends
  /// more than this without completing frames is dropped.
  static const int maxBufferedBytes = 4 * maxFrameBytes;

  /// Most frames handled by one drain, so a flooding peer cannot keep the
  /// caller busy forever.
  static const int maxFramesPerDrain = 32;
}

class DiscordIpcProtocolException implements Exception {
  final String message;
  const DiscordIpcProtocolException(this.message);
  @override
  String toString() => 'DiscordIpcProtocolException: $message';
}

class DiscordIpcFrame {
  final int opcode;
  final String payload;
  const DiscordIpcFrame(this.opcode, this.payload);

  /// The payload as a JSON object, or null when it is not one.
  Map<String, dynamic>? get json {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

/// Builds one frame. Throws [DiscordIpcProtocolException] for an invalid
/// opcode or a payload over [DiscordIpcLimits.maxFrameBytes].
Uint8List encodeDiscordIpcFrame(int opcode, String payload) {
  if (!DiscordIpcOpcode.isValid(opcode)) {
    throw DiscordIpcProtocolException('invalid opcode $opcode');
  }
  final body = utf8.encode(payload);
  if (body.length > DiscordIpcLimits.maxFrameBytes) {
    throw DiscordIpcProtocolException('outgoing frame of ${body.length} bytes is over the limit');
  }
  final out = Uint8List(8 + body.length);
  final header = ByteData.sublistView(out, 0, 8);
  header.setUint32(0, opcode, Endian.little);
  header.setUint32(4, body.length, Endian.little);
  out.setRange(8, out.length, body);
  return out;
}

/// Incremental frame parser: bytes go in as they arrive, in chunks of any
/// size; complete frames come out of [next].
///
/// After the first protocol error the decoder stays failed and every call
/// throws again: the stream position is unknown, so the connection must be
/// closed.
class DiscordIpcFrameDecoder {
  Uint8List _buf = Uint8List(0);
  int _start = 0;
  int _end = 0;
  DiscordIpcProtocolException? _failure;

  /// Bytes received but not yet returned as frames.
  int get bufferedBytes => _end - _start;

  bool get hasFailed => _failure != null;

  void add(List<int> chunk) {
    _throwIfFailed();
    if (chunk.isEmpty) return;
    if (bufferedBytes + chunk.length > DiscordIpcLimits.maxBufferedBytes) {
      _fail('more than ${DiscordIpcLimits.maxBufferedBytes} unparsed bytes');
    }
    final needed = bufferedBytes + chunk.length;
    if (_end + chunk.length > _buf.length) {
      // Compact, and grow only when the live data really needs it.
      final capacity = needed > _buf.length ? _grow(needed) : _buf.length;
      final next = Uint8List(capacity);
      next.setRange(0, bufferedBytes, _buf, _start);
      _buf = next;
      _end = bufferedBytes;
      _start = 0;
    }
    _buf.setRange(_end, _end + chunk.length, chunk);
    _end += chunk.length;
  }

  int _grow(int needed) {
    var capacity = _buf.isEmpty ? 1024 : _buf.length;
    while (capacity < needed) {
      capacity *= 2;
    }
    return capacity > DiscordIpcLimits.maxBufferedBytes
        ? DiscordIpcLimits.maxBufferedBytes
        : capacity;
  }

  /// The next complete frame, or null when more bytes are needed.
  DiscordIpcFrame? next() {
    _throwIfFailed();
    if (bufferedBytes < 8) return null;
    final header = ByteData.sublistView(_buf, _start, _start + 8);
    final opcode = header.getUint32(0, Endian.little);
    final length = header.getUint32(4, Endian.little);
    // Validate the header before waiting for (or allocating) the body.
    if (!DiscordIpcOpcode.isValid(opcode)) _fail('invalid opcode $opcode');
    if (length > DiscordIpcLimits.maxFrameBytes) {
      _fail('incoming frame of $length bytes is over the limit');
    }
    if (bufferedBytes < 8 + length) return null;

    final bodyStart = _start + 8;
    final String payload;
    try {
      payload = utf8.decode(Uint8List.sublistView(_buf, bodyStart, bodyStart + length));
    } on FormatException {
      _fail('payload is not valid UTF-8');
    }
    _start = bodyStart + length;
    if (_start == _end) {
      _start = 0;
      _end = 0;
    }
    return DiscordIpcFrame(opcode, payload);
  }

  Never _fail(String message) {
    final failure = DiscordIpcProtocolException(message);
    _failure = failure;
    _buf = Uint8List(0);
    _start = 0;
    _end = 0;
    throw failure;
  }

  void _throwIfFailed() {
    final failure = _failure;
    if (failure != null) throw failure;
  }
}

/// True when [frame] is Discord's answer to a successful handshake: a FRAME
/// carrying `{"cmd": "DISPATCH", "evt": "READY", "data": {...}}`.
///
/// Anything else (a CLOSE with an error code, an ERROR event, a frame of the
/// wrong type, or a payload that is not that object) means the peer is not
/// a Discord client that accepted this application.
bool isDiscordReadyFrame(DiscordIpcFrame? frame) {
  if (frame == null || frame.opcode != DiscordIpcOpcode.frame) return false;
  final json = frame.json;
  if (json == null) return false;
  return json['cmd'] == 'DISPATCH' && json['evt'] == 'READY' && json['data'] is Map;
}

/// A byte stream to a Discord client: a named pipe on Windows, a Unix domain
/// socket elsewhere, or a fake in tests.
abstract class DiscordIpcTransport {
  /// Writes all of [bytes]. False when the connection is gone.
  Future<bool> write(Uint8List bytes);

  /// Waits up to [wait] for data and returns what is available, possibly
  /// empty. Null when the connection is closed.
  Future<Uint8List?> read(Duration wait);

  void close();
}

/// Frames over a [DiscordIpcTransport].
///
/// Any protocol error, closed transport or CLOSE frame marks the connection
/// as closed; callers then drop it and reconnect later.
class DiscordIpcConnection {
  DiscordIpcConnection(this._transport);

  final DiscordIpcTransport _transport;
  final DiscordIpcFrameDecoder _decoder = DiscordIpcFrameDecoder();
  bool _closed = false;

  bool get isClosed => _closed;

  Future<bool> writeFrame(int opcode, String payload) async {
    if (_closed) return false;
    final Uint8List bytes;
    try {
      bytes = encodeDiscordIpcFrame(opcode, payload);
    } on DiscordIpcProtocolException {
      // Our own payload is too big: refuse it, the connection is still fine.
      return false;
    }
    try {
      final ok = await _transport.write(bytes);
      if (!ok) close();
      return ok;
    } catch (_) {
      close();
      return false;
    }
  }

  /// The next frame, waiting up to [timeout]. Null on timeout, protocol
  /// error or closed connection (check [isClosed] to tell them apart).
  Future<DiscordIpcFrame?> readFrame(Duration timeout) async {
    final stopwatch = Stopwatch()..start();
    var readOnce = false;
    while (!_closed) {
      try {
        final frame = _decoder.next();
        if (frame != null) return frame;
      } on DiscordIpcProtocolException {
        close();
        return null;
      }
      var remaining = timeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        // A zero timeout still looks at what is already available, once.
        if (readOnce) return null;
        remaining = Duration.zero;
      }
      readOnce = true;
      final Uint8List? chunk;
      try {
        chunk = await _transport.read(remaining);
      } catch (_) {
        close();
        return null;
      }
      if (chunk == null) {
        close();
        return null;
      }
      try {
        _decoder.add(chunk);
      } on DiscordIpcProtocolException {
        close();
        return null;
      }
    }
    return null;
  }

  /// Handles whatever Discord has sent so far without waiting: replies to
  /// commands are discarded (left unread they fill the pipe), PINGs are
  /// answered, and a CLOSE ends the connection. Returns false when the
  /// connection is gone.
  Future<bool> drain() async {
    for (var i = 0; i < DiscordIpcLimits.maxFramesPerDrain && !_closed; i++) {
      final frame = await readFrame(Duration.zero);
      if (frame == null) break;
      if (frame.opcode == DiscordIpcOpcode.close) {
        close();
      } else if (frame.opcode == DiscordIpcOpcode.ping) {
        await writeFrame(DiscordIpcOpcode.pong, frame.payload);
      }
    }
    return !_closed;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _transport.close();
    } catch (_) {}
  }
}

/// Transport over a socket (Unix domain socket on Linux and macOS).
///
/// Incoming bytes are buffered as they arrive, up to
/// [DiscordIpcLimits.maxBufferedBytes]; past that the socket is dropped.
class DiscordSocketTransport implements DiscordIpcTransport {
  DiscordSocketTransport(this._socket) {
    _subscription = _socket.listen(
      (data) {
        _pendingBytes += data.length;
        if (_pendingBytes > DiscordIpcLimits.maxBufferedBytes) {
          close();
          return;
        }
        _pending.add(data);
        _wake();
      },
      onError: (_) => close(),
      onDone: close,
      cancelOnError: true,
    );
  }

  final Socket _socket;
  late final StreamSubscription<Uint8List> _subscription;
  final List<Uint8List> _pending = [];
  int _pendingBytes = 0;
  Completer<void>? _signal;
  bool _closed = false;

  void _wake() {
    _signal?.complete();
    _signal = null;
  }

  @override
  Future<bool> write(Uint8List bytes) async {
    if (_closed) return false;
    try {
      _socket.add(bytes);
      await _socket.flush();
      return true;
    } catch (_) {
      close();
      return false;
    }
  }

  @override
  Future<Uint8List?> read(Duration wait) async {
    if (_pending.isEmpty && !_closed && wait > Duration.zero) {
      final signal = _signal ??= Completer<void>();
      try {
        await signal.future.timeout(wait);
      } on TimeoutException {
        // Return whatever arrived (possibly nothing).
      }
    }
    if (_pending.isEmpty) return _closed ? null : Uint8List(0);
    final builder = BytesBuilder(copy: false);
    for (final chunk in _pending) {
      builder.add(chunk);
    }
    _pending.clear();
    _pendingBytes = 0;
    return builder.takeBytes();
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _pending.clear();
    _pendingBytes = 0;
    _wake();
    unawaited(_subscription.cancel().catchError((_) {}));
    try {
      _socket.destroy();
    } catch (_) {}
  }
}
