import '../models/media_item.dart';

class RecentFilesService {
  static const maxRecentFiles = 10;
  static List<MediaItem> _recentFiles = [];

  static void addFile(MediaItem item) {
    _recentFiles.removeWhere((file) => file.url == item.url);
    _recentFiles.insert(0, item);
    if (_recentFiles.length > maxRecentFiles) {
      _recentFiles = _recentFiles.sublist(0, maxRecentFiles);
    }
  }

  static List<MediaItem> getRecentFiles() => List.unmodifiable(_recentFiles);
}