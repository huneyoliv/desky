import 'dart:io';

import 'app_text_styles.dart';

const timerBackgroundTheme = 'theme';
const timerBackgroundAurora = 'aurora';
const timerBackgroundSunset = 'sunset';
const timerBackgroundCustomImage = 'custom_image';
const timerBackgroundCustomVideo = 'custom_video';

const timerFontDigital = 'digital';
const timerFontSfPro = 'sf_pro';
const timerFontPretendard = 'pretendard';

const _backgrounds = {
  timerBackgroundTheme,
  timerBackgroundAurora,
  timerBackgroundSunset,
  timerBackgroundCustomImage,
  timerBackgroundCustomVideo,
};
const _fonts = {timerFontDigital, timerFontSfPro, timerFontPretendard};

String normalizeTimerBackground(String? value) =>
    _backgrounds.contains(value) ? value! : timerBackgroundTheme;

String normalizeTimerFont(String? value) =>
    _fonts.contains(value) ? value! : timerFontDigital;

const maxTimerBackgroundBytes = 20 * 1024 * 1024;
const maxTimerBackgroundVideoBytes = 50 * 1024 * 1024;

Future<bool> isValidTimerBackgroundVideoFile(
  String path, {
  int maxBytes = maxTimerBackgroundVideoBytes,
}) async {
  final extension = path.split('.').last.toLowerCase();
  if (!{'mp4', 'webm'}.contains(extension)) return false;
  try {
    if (await FileSystemEntity.type(path) != FileSystemEntityType.file) return false;
    final size = await File(path).length();
    return size > 0 && size <= maxBytes;
  } catch (_) {
    return false;
  }
}

Future<bool> isValidTimerBackgroundImageFile(
  String path, {
  int maxBytes = maxTimerBackgroundBytes,
}) async {
  final extension = path.split('.').last.toLowerCase();
  if (!{'png', 'jpg', 'jpeg', 'webp'}.contains(extension)) return false;
  try {
    final size = await File(path).length();
    return size > 0 && size <= maxBytes;
  } catch (_) {
    return false;
  }
}

String timerFontFamilyName(String? value) {
  switch (normalizeTimerFont(value)) {
    case timerFontSfPro:
      return AppTextStyles.fontDisplay;
    case timerFontPretendard:
      return 'Pretendard';
    default:
      return AppTextStyles.fontTimer;
  }
}
