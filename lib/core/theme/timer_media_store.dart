import 'dart:io';

import 'package:path_provider/path_provider.dart';

class TimerMediaStore {
  TimerMediaStore(this.root);

  final Directory root;

  Directory get mediaDirectory => Directory('${root.path}/timer_media');

  static Future<TimerMediaStore> application() async {
    return TimerMediaStore(await getApplicationSupportDirectory());
  }

  Future<String> importMedia(
    String sourcePath, {
    String? previousOwnedPath,
  }) async {
    final source = File(sourcePath);
    await mediaDirectory.create(recursive: true);
    final extension = sourcePath.split('.').last.toLowerCase();
    final destination = File(
      '${mediaDirectory.path}/${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    final imported = await source.copy(destination.path);
    await deleteOwned(previousOwnedPath);
    return imported.path;
  }

  Future<void> deleteOwned(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (file.parent.absolute.path != mediaDirectory.absolute.path) return;
    if (await file.exists()) await file.delete();
  }
}
