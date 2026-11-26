import 'dart:io';

import 'package:desky/core/theme/timer_media_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports media into app storage and removes only replaced owned files',
      () async {
    final root = Directory('build/test_timer_media_store');
    await root.create(recursive: true);
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final external = File('${root.path}/external.mp4');
    await external.writeAsBytes(const [1, 2, 3]);
    final store = TimerMediaStore(root);

    final first = await store.importMedia(external.path);
    final second =
        await store.importMedia(external.path, previousOwnedPath: first);

    expect(first, isNot(second));
    expect(await File(second).exists(), isTrue);
    expect(await File(first).exists(), isFalse);
    expect(await external.exists(), isTrue);

    await store.deleteOwned(external.path);
    expect(await external.exists(), isTrue);
  });
}
