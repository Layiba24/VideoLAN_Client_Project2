import 'package:flutter/foundation.dart';
import 'media_item.dart';

class PlaylistManager extends ChangeNotifier {
  List<MediaItem> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _loop = false;
  bool _shuffle = false;

  List<MediaItem> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get loop => _loop;
  bool get shuffle => _shuffle;
  MediaItem? get currentItem => _playlist.isEmpty ? null : _playlist[_currentIndex];

  void addItem(MediaItem item) {
    _playlist.add(item);
    notifyListeners();
  }

  void removeItem(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _playlist.removeAt(index);
    if (_currentIndex == index) {
      _currentIndex = 0;
    } else if (_currentIndex > index) {
      _currentIndex--;
    }
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    notifyListeners();
  }

  void next() {
    if (_playlist.isEmpty) return;
    if (_shuffle) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch % _playlist.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _playlist.length;
    }
    notifyListeners();
  }

  void previous() {
    if (_playlist.isEmpty) return;
    if (_shuffle) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch % _playlist.length);
    } else {
      _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    }
    notifyListeners();
  }

  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    notifyListeners();
  }

  void toggleLoop() {
    _loop = !_loop;
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void clear() {
    _playlist.clear();
    _currentIndex = 0;
    _isPlaying = false;
    notifyListeners();
  }
}