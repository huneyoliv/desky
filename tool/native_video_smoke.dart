import 'dart:async';
import 'dart:io';

import 'package:desky/features/timer/widgets/timer_video_background.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = MediaKitTimerVideoBackend();
  final errors = <Object?>[];
  final subscription = backend.errors.listen(errors.add);
  var decoded = false;
  final watchdog = Timer(const Duration(seconds: 20), () {
    debugPrint('NATIVE_VIDEO_RESULT decoded=$decoded errors=${errors.length} watchdog=true');
    exit(2);
  });
  try {
    runApp(const MaterialApp(home: SizedBox()));
    debugPrint('NATIVE_VIDEO_STEP mute');
    await backend.setMuted(true);
    debugPrint('NATIVE_VIDEO_STEP loop');
    await backend.setLooping(true);
    debugPrint('NATIVE_VIDEO_STEP open');
    await backend
        .open(File('test/fixtures/intro_scene3.mp4').absolute.path)
        .timeout(const Duration(seconds: 10));
    debugPrint('NATIVE_VIDEO_STEP play');
    await backend.play();
    debugPrint('NATIVE_VIDEO_STEP runApp');
    runApp(MaterialApp(home: Builder(builder: backend.build)));
    await Future<void>.delayed(const Duration(seconds: 4));
    decoded = backend.hasVideoFrame;
  } catch (error) {
    errors.add(error);
  }
  final resultFile = Platform.environment['DESKY_NATIVE_VIDEO_RESULT_FILE'];
  if (resultFile != null) {
    File(resultFile).writeAsStringSync('decoded=$decoded errors=${errors.length}\n');
  }
  debugPrint("NATIVE_VIDEO_ERRORS ${errors.join(' | ')}");
  debugPrint('NATIVE_VIDEO_RESULT decoded=$decoded errors=${errors.length}');
  watchdog.cancel();
  await subscription.cancel().timeout(const Duration(seconds: 1));
  await backend.dispose().timeout(const Duration(seconds: 3));
  exit(decoded && errors.isEmpty ? 0 : 1);
}
