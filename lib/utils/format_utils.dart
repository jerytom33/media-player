import 'dart:io';

class FormatUtils {
  static String formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  static String getDisplayName(String? filePath) {
    if (filePath == null) return '';
    if (filePath.startsWith('content://')) {
      return filePath.split('/').last;
    }
    return filePath.split(Platform.pathSeparator).last;
  }
}
