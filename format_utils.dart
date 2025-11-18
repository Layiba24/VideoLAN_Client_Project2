class TimeUtils {
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  static String formatTime(num seconds) {
    if (seconds.isNaN || seconds.isInfinite) return '00:00';
    final s = seconds.floor();
    final m = s ~/ 60;
    final sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class FileUtils {
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static bool isVideoFile(String fileName) {
    final validExtensions = [
      '.mp4', '.mkv', '.avi', '.mov',
      '.wmv', '.flv', '.webm', '.m4v',
      '.3gp', '.mpg', '.mpeg', '.m2v',
    ];
    return validExtensions.any((ext) => fileName.toLowerCase().endsWith(ext));
  }
}