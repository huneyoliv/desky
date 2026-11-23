import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desky/core/services/discord_ipc_protocol.dart';
import 'package:desky/core/services/discord_rpc_service.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _header(int opcode, int length) {
  final b = Uint8List(8);
  ByteData.sublistView(b)
    ..setUint32(0, opcode, Endian.little)
    ..setUint32(4, length, Endian.little);
  return b;
}

Uint8List _frame(int opcode, Object json) =>
    encodeDiscordIpcFrame(opcode, json is String ? json : jsonEncode(json));

final Map<String, Object> _ready = {
  'cmd': 'DISPATCH',
  'evt': 'READY',
  'data': {'v': 1, 'user': {'id': '1'}},
};

/// A scripted peer. [onWrite] can push replies in answer to what we send.
class _FakeTransport implements DiscordIpcTransport {
  final List<Uint8List> inbox = [];
  final List<DiscordIpcFrame> written = [];
  void Function(_FakeTransport t, DiscordIpcFrame frame)? onWrite;
  bool closed = false;
  bool failWrites = false;

  void push(List<int> bytes) => inbox.add(Uint8List.fromList(bytes));

  @override
  Future<bool> write(Uint8List bytes) async {
    if (closed || failWrites) return false;
    final d = DiscordIpcFrameDecoder()..add(bytes);
    final frame = d.next()!;
    written.add(frame);
    onWrite?.call(this, frame);
    return true;
  }

  @override
  Future<Uint8List?> read(Duration wait) async {
    if (closed) return null;
    if (inbox.isEmpty) {
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait > const Duration(milliseconds: 50)
            ? const Duration(milliseconds: 50)
            : wait);
      }
      return closed ? null : Uint8List(0);
    }
    return inbox.removeAt(0);
  }

  @override
  void close() => closed = true;
}

DiscordPresencePayload _payload([String details = 'Math']) => DiscordPresencePayload(
      details: details,
      state: 'Studying',
      largeImage: 'https://example.com/a.png',
      largeText: 'Today: 01h 00m',
    );

void main() {
  group('frame decoder', () {
    test('round-trips frames, including non-ASCII payloads', () {
      final d = DiscordIpcFrameDecoder()..add(_frame(1, {'t': 'Matemática ✓'}));
      final f = d.next()!;
      expect(f.opcode, 1);
      expect(f.json!['t'], 'Matemática ✓');
      expect(d.next(), isNull);
      expect(d.bufferedBytes, 0);
    });

    test('parses a frame delivered one byte at a time', () {
      final bytes = _frame(1, _ready);
      final d = DiscordIpcFrameDecoder();
      for (var i = 0; i < bytes.length - 1; i++) {
        d.add([bytes[i]]);
        expect(d.next(), isNull, reason: 'incomplete at byte $i');
      }
      d.add([bytes.last]);
      expect(isDiscordReadyFrame(d.next()), isTrue);
    });

    test('parses several frames from one chunk, and a split tail', () {
      final a = _frame(1, {'n': 1});
      final b = _frame(3, {'n': 2});
      final c = _frame(1, {'n': 3});
      final d = DiscordIpcFrameDecoder()
        ..add([...a, ...b, ...c.sublist(0, 5)]);
      expect(d.next()!.json!['n'], 1);
      expect(d.next()!.opcode, 3);
      expect(d.next(), isNull);
      d.add(c.sublist(5));
      expect(d.next()!.json!['n'], 3);
    });

    test('accepts an empty payload', () {
      final d = DiscordIpcFrameDecoder()..add(_header(2, 0));
      final f = d.next()!;
      expect(f.opcode, 2);
      expect(f.payload, '');
      expect(f.json, isNull);
    });

    test('rejects an oversized length from the header alone, before any body', () {
      final d = DiscordIpcFrameDecoder()..add(_header(1, 0xFFFFFFFF));
      expect(d.next, throwsA(isA<DiscordIpcProtocolException>()));
      expect(d.hasFailed, isTrue);
      expect(d.bufferedBytes, 0);
    });

    test('rejects a length one byte over the limit', () {
      final d = DiscordIpcFrameDecoder()
        ..add(_header(1, DiscordIpcLimits.maxFrameBytes + 1));
      expect(d.next, throwsA(isA<DiscordIpcProtocolException>()));
    });

    test('rejects unknown opcodes', () {
      final d = DiscordIpcFrameDecoder()
        ..add(_header(5, 2))
        ..add([0x7b, 0x7d]);
      expect(d.next, throwsA(isA<DiscordIpcProtocolException>()));
    });

    test('rejects invalid UTF-8', () {
      final d = DiscordIpcFrameDecoder()
        ..add(_header(1, 2))
        ..add([0xC3, 0x28]);
      expect(d.next, throwsA(isA<DiscordIpcProtocolException>()));
    });

    test('caps unparsed data and stays failed afterwards', () {
      final d = DiscordIpcFrameDecoder();
      // Valid header for a max-size frame, then dribble more than the buffer
      // cap without ever completing frames in between.
      final chunk = Uint8List(DiscordIpcLimits.maxFrameBytes);
      expect(() {
        for (var i = 0; i < 10; i++) {
          d.add(chunk);
        }
      }, throwsA(isA<DiscordIpcProtocolException>()));
      expect(d.hasFailed, isTrue);
      expect(() => d.add([1]), throwsA(isA<DiscordIpcProtocolException>()));
      expect(d.next, throwsA(isA<DiscordIpcProtocolException>()));
    });

    test('a max-size frame is accepted', () {
      final body = 'x' * DiscordIpcLimits.maxFrameBytes;
      final d = DiscordIpcFrameDecoder()..add(encodeDiscordIpcFrame(1, body));
      expect(d.next()!.payload.length, DiscordIpcLimits.maxFrameBytes);
    });
  });

  group('frame encoder', () {
    test('refuses oversized payloads and invalid opcodes', () {
      expect(() => encodeDiscordIpcFrame(1, 'x' * (DiscordIpcLimits.maxFrameBytes + 1)),
          throwsA(isA<DiscordIpcProtocolException>()));
      expect(() => encodeDiscordIpcFrame(9, '{}'), throwsA(isA<DiscordIpcProtocolException>()));
    });
  });

  group('handshake validation', () {
    DiscordIpcFrame f(int op, String payload) => DiscordIpcFrame(op, payload);

    test('accepts only a READY dispatch with data', () {
      expect(isDiscordReadyFrame(f(1, jsonEncode(_ready))), isTrue);
    });

    test('rejects everything else', () {
      expect(isDiscordReadyFrame(null), isFalse);
      // Discord's answer for an unknown client id.
      expect(isDiscordReadyFrame(f(2, '{"code":4000,"message":"Invalid Client ID"}')), isFalse);
      expect(
          isDiscordReadyFrame(
              f(1, '{"cmd":"DISPATCH","evt":"ERROR","data":{"code":4000}}')),
          isFalse);
      // READY but on the wrong opcode.
      expect(isDiscordReadyFrame(f(3, jsonEncode(_ready))), isFalse);
      expect(isDiscordReadyFrame(f(1, '{"cmd":"DISPATCH","evt":"READY"}')), isFalse);
      expect(isDiscordReadyFrame(f(1, '[]')), isFalse);
      expect(isDiscordReadyFrame(f(1, 'not json')), isFalse);
      expect(isDiscordReadyFrame(f(1, '')), isFalse);
    });
  });

  group('DiscordRpcService against hostile peers', () {
    late List<_FakeTransport> opened;

    DiscordRpcService service(void Function(_FakeTransport t) setup) {
      opened = [];
      return DiscordRpcService(
        clientId: '123',
        handshakeTimeout: const Duration(milliseconds: 300),
        connector: () async {
          final t = _FakeTransport();
          setup(t);
          opened.add(t);
          return t;
        },
      );
    }

    void answerReady(_FakeTransport t) {
      t.onWrite = (t, frame) {
        if (frame.opcode == DiscordIpcOpcode.handshake) t.push(_frame(1, _ready));
      };
    }

    test('connects on a valid READY, sending the documented handshake', () async {
      final s = service(answerReady);
      await s.connect();
      expect(s.isConnected, isTrue);
      final hs = opened.single.written.first;
      expect(hs.opcode, DiscordIpcOpcode.handshake);
      expect(hs.json, {'v': 1, 'client_id': '123'});
    });

    test('READY split across reads still connects', () async {
      final s = service((t) {
        t.onWrite = (t, frame) {
          if (frame.opcode != 0) return;
          final bytes = _frame(1, _ready);
          t.push(bytes.sublist(0, 3));
          t.push(bytes.sublist(3, 12));
          t.push(bytes.sublist(12));
        };
      });
      await s.connect();
      expect(s.isConnected, isTrue);
    });

    for (final entry in <String, List<int> Function()>{
      'CLOSE with an error': () => _frame(2, {'code': 4000, 'message': 'Invalid Client ID'}),
      'ERROR event': () => _frame(1, {'cmd': 'DISPATCH', 'evt': 'ERROR', 'data': {}}),
      'oversized header': () => _header(1, 0x7FFFFFFF),
      'unknown opcode': () => [..._header(42, 2), 0x7b, 0x7d],
      'invalid UTF-8': () => [..._header(1, 2), 0xFF, 0xFE],
      'non-JSON payload': () => _frame(1, 'hello'),
    }.entries) {
      test('refuses a handshake answered with ${entry.key}', () async {
        final s = service((t) {
          t.onWrite = (t, frame) {
            if (frame.opcode == 0) t.push(entry.value());
          };
        });
        await s.connect();
        expect(s.isConnected, isFalse);
        expect(opened.single.closed, isTrue);

        await s.updatePresence(_payload());
        expect(opened.every((t) => t.written.every((f) => f.opcode == 0)), isTrue,
            reason: 'no SET_ACTIVITY is ever sent to an unverified peer');
      });
    }

    test('gives up on a peer that never answers the handshake', () async {
      final s = service((_) {});
      final sw = Stopwatch()..start();
      await s.connect();
      expect(s.isConnected, isFalse);
      expect(opened.single.closed, isTrue);
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    });

    test('sends SET_ACTIVITY and discards the replies', () async {
      final s = service((t) {
        t.onWrite = (t, frame) {
          if (frame.opcode == 0) t.push(_frame(1, _ready));
          if (frame.opcode == 1) {
            t.push(_frame(1, {'cmd': 'SET_ACTIVITY', 'evt': null, 'nonce': frame.json!['nonce']}));
          }
        };
      });
      await s.updatePresence(_payload('A'));
      await s.updatePresence(_payload('B'));
      final t = opened.single;
      final cmds = t.written.where((f) => f.opcode == 1).toList();
      expect(cmds.map((f) => f.json!['args']['activity']['details']), ['A', 'B']);
      expect(cmds.map((f) => f.json!['nonce']).toSet(), hasLength(2));
      expect(s.isConnected, isTrue);
    });

    test('answers PING with PONG carrying the same payload', () async {
      final s = service(answerReady);
      await s.connect();
      final t = opened.single;
      t.push(_frame(3, {'p': 7}));
      await s.updatePresence(_payload());
      final pong = t.written.firstWhere((f) => f.opcode == DiscordIpcOpcode.pong);
      expect(pong.json, {'p': 7});
    });

    test('a CLOSE mid-session drops the connection; the next update reconnects', () async {
      final s = service(answerReady);
      await s.updatePresence(_payload('A'));
      opened.first.push(_frame(2, {'code': 1000}));

      await s.updatePresence(_payload('B'));
      expect(opened.first.closed, isTrue);
      // B was not acknowledged on the dead connection, so it is retried.
      await s.updatePresence(_payload('B'));
      expect(opened, hasLength(2));
      expect(s.isConnected, isTrue);
      expect(opened.last.written.where((f) => f.opcode == 1).single.json!['args']['activity']['details'], 'B');
    });

    test('garbage mid-session drops the connection instead of desyncing', () async {
      final s = service(answerReady);
      await s.connect();
      opened.single.push(_header(1, 0xFFFFFF00));
      await s.updatePresence(_payload());
      expect(opened.single.closed, isTrue);
      expect(s.isConnected, isFalse);
    });

    test('a flood of replies is drained in bounded steps without hanging', () async {
      final s = service(answerReady);
      await s.connect();
      final t = opened.single;
      for (var i = 0; i < 500; i++) {
        t.push(_frame(1, {'evt': null, 'i': i}));
      }
      await s.updatePresence(_payload()).timeout(const Duration(seconds: 2));
      expect(s.isConnected, isTrue);
    });

    test('a failed write drops the connection', () async {
      final s = service(answerReady);
      await s.connect();
      opened.single.failWrites = true;
      await s.updatePresence(_payload());
      expect(s.isConnected, isFalse);
      expect(opened.single.closed, isTrue);
    });

    test('an oversized outgoing activity is refused without killing the connection', () async {
      final s = service(answerReady);
      await s.connect();
      await s.updatePresence(_payload('x' * (DiscordIpcLimits.maxFrameBytes + 10)));
      expect(opened.single.written.where((f) => f.opcode == 1), isEmpty);
      expect(s.isConnected, isTrue);
    });

    test('no connector result means not connected, no crash', () async {
      final s = DiscordRpcService(clientId: '1', connector: () async => null);
      await s.connect();
      await s.updatePresence(_payload());
      await s.clearPresence();
      expect(s.isConnected, isFalse);
      s.dispose();
    });
  });

  group('socket transport (Unix domain socket)', () {
    late Directory dir;
    late ServerSocket server;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('discord_ipc_test');
      server = await ServerSocket.bind(
        InternetAddress('${dir.path}/ipc', type: InternetAddressType.unix),
        0,
      );
    });

    tearDown(() async {
      await server.close();
      await dir.delete(recursive: true);
    });

    Future<DiscordIpcConnection> connect() async {
      final socket = await Socket.connect(
        InternetAddress('${dir.path}/ipc', type: InternetAddressType.unix),
        0,
      );
      return DiscordIpcConnection(DiscordSocketTransport(socket));
    }

    test('reassembles frames the peer writes in fragments', () async {
      server.listen((peer) async {
        final bytes = [..._frame(1, _ready), ..._frame(1, {'n': 2})];
        for (var i = 0; i < bytes.length; i += 7) {
          peer.add(bytes.sublist(i, i + 7 > bytes.length ? bytes.length : i + 7));
          await peer.flush();
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      });
      final c = await connect();
      expect(isDiscordReadyFrame(await c.readFrame(const Duration(seconds: 2))), isTrue);
      expect((await c.readFrame(const Duration(seconds: 2)))!.json!['n'], 2);
      c.close();
    });

    test('drops a peer that floods past the buffer cap', () async {
      server.listen((peer) async {
        try {
          final junk = Uint8List(64 * 1024);
          for (var i = 0; i < 16; i++) {
            peer.add(junk);
            await peer.flush();
          }
        } catch (_) {}
      });
      final c = await connect();
      // Do not read: let the transport buffer until it gives up. The junk is
      // zeros, which would parse as empty frames if anything got through.
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(await c.readFrame(Duration.zero), isNull);
      expect(c.isClosed, isTrue);
    });

    test('peer hang-up is reported as closed', () async {
      server.listen((peer) => peer.destroy());
      final c = await connect();
      expect(await c.readFrame(const Duration(seconds: 2)), isNull);
      expect(c.isClosed, isTrue);
    });
  }, skip: Platform.isWindows ? 'Unix domain sockets only' : false);
}
