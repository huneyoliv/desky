import 'package:flutter/material.dart';
import '../../features/smartbook/smartbook_screen.dart';

class SmartBookWindowService {
  SmartBookWindowService._();

  static Future<void> open(BuildContext context, {String? filePath}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SmartBookScreen(initialFilePath: filePath),
      ),
    );
  }
}
