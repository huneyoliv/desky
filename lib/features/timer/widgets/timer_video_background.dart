import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

abstract interface class TimerVideoBackend {
  Stream<Object?> get errors;
  Future<void> open(String path);
  Future<void> setMuted(bool value);
  Future<void> setLooping(bool value);
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
  Widget build(BuildContext context);
}

typedef TimerVideoBackendFactory = TimerVideoBackend Function();

class MediaKitTimerVideoBackend implements TimerVideoBackend {
  Player? _player;
  VideoController? _controller;
  StreamSubscription<dynamic>? _errorSubscription;
  final _errors = StreamController<Object?>.broadcast();
  bool _disposed = false;

  @override
  Stream<Object?> get errors => _errors.stream;

  bool get hasVideoFrame {
    final state = _player?.state;
    return (state?.width ?? 0) > 0 && (state?.height ?? 0) > 0;
  }

  void _ensurePlayer() {
    if (_player != null) return;
    MediaKit.ensureInitialized();
    final player = Player();
    try {
      _controller = VideoController(player);
      _player = player;
      _errorSubscription = player.stream.error.listen((error) {
        if (!_disposed) _errors.add(error);
      });
    } catch (_) {
      player.dispose();
      rethrow;
    }
  }

  @override
  Future<void> open(String path) async {
    _ensurePlayer();
    if (!await File(path).exists()) {
      throw StateError('Video file does not exist');
    }
    await _player!.open(Media(File(path).uri.toString()), play: false);
  }

  @override
  Future<void> setMuted(bool value) async {
    _ensurePlayer();
    await _player?.setVolume(value ? 0 : 100);
  }

  @override
  Future<void> setLooping(bool value) async {
    _ensurePlayer();
    await _player?.setPlaylistMode(
      value ? PlaylistMode.single : PlaylistMode.none,
    );
  }

  @override
  Future<void> play() async {
    if (!_disposed) await _player?.play();
  }

  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return Video(
      controller: controller,
      fit: BoxFit.cover,
      controls: NoVideoControls,
      wakelock: false,
      pauseUponEnteringBackgroundMode: false,
      resumeUponEnteringForegroundMode: false,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _errorSubscription?.cancel();
    await _errors.close();
    await _player?.dispose();
  }
}

class TimerVideoBackground extends StatefulWidget {
  const TimerVideoBackground({
    super.key,
    required this.path,
    required this.fallback,
    this.backendFactory = MediaKitTimerVideoBackend.new,
    this.openTimeout = const Duration(seconds: 10),
  });

  final String path;
  final Widget fallback;
  final TimerVideoBackendFactory backendFactory;
  final Duration openTimeout;

  @override
  State<TimerVideoBackground> createState() => _TimerVideoBackgroundState();
}

class _TimerVideoBackgroundState extends State<TimerVideoBackground>
    with WidgetsBindingObserver {
  TimerVideoBackend? _backend;
  StreamSubscription<Object?>? _errorSubscription;
  int _generation = 0;
  bool _ready = false;
  bool _failed = false;
  bool _background = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void didUpdateWidget(TimerVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.backendFactory != widget.backendFactory) {
      _open();
    }
  }

  bool _isCurrent(int generation) =>
      mounted && !_disposed && generation == _generation;

  Future<void> _open() async {
    final generation = ++_generation;
    _ready = false;
    _failed = false;
    await _disposeBackend();
    if (!_isCurrent(generation)) return;

    final backend = widget.backendFactory();
    _backend = backend;
    _errorSubscription = backend.errors.listen(
      (_) => _fail(generation),
      onError: (_, __) => _fail(generation),
    );

    try {
      await backend.setMuted(true);
      await backend.setLooping(true);
      await backend.open(widget.path).timeout(widget.openTimeout);
      if (!_isCurrent(generation)) return;
      if (!_background) await backend.play();
      if (!_isCurrent(generation)) return;
      setState(() => _ready = true);
    } catch (_) {
      await _fail(generation);
    }
  }

  Future<void> _fail(int generation) async {
    if (!_isCurrent(generation)) return;
    setState(() {
      _ready = false;
      _failed = true;
    });
    await _disposeBackend();
  }

  Future<void> _disposeBackend() async {
    final backend = _backend;
    _backend = null;
    final disposal = backend?.dispose();
    unawaited(_errorSubscription?.cancel());
    _errorSubscription = null;
    await disposal;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _background = true;
      unawaited(_backend?.pause());
      return;
    }
    if (state == AppLifecycleState.detached) {
      _background = true;
      _generation++;
      unawaited(_disposeBackend());
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _background = false;
      if (_backend == null) {
        _failed = false;
        _open();
      } else if (!_failed) {
        unawaited(_backend?.play());
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeBackend());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backend = _backend;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.fallback,
        if (_ready && !_failed && backend != null)
          Builder(builder: backend.build),
      ],
    );
  }
}
