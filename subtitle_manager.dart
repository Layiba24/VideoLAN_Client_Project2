import 'package:flutter/foundation.dart';

class SubtitleTrack {
  final String label;
  final String language;
  final String source;
  final String? type; // 'vtt', 'srt', etc.

  SubtitleTrack({
    required this.label,
    required this.language,
    required this.source,
    this.type,
  });
}

class SubtitleManager extends ChangeNotifier {
  List<SubtitleTrack> _tracks = [];
  int? _currentTrackIndex;
  bool _enabled = false;
  double _delay = 0; // in seconds

  List<SubtitleTrack> get tracks => List.unmodifiable(_tracks);
  SubtitleTrack? get currentTrack => _currentTrackIndex != null ? _tracks[_currentTrackIndex!] : null;
  bool get enabled => _enabled;
  double get delay => _delay;

  void addTrack(SubtitleTrack track) {
    _tracks.add(track);
    notifyListeners();
  }

  void removeTrack(int index) {
    if (index < 0 || index >= _tracks.length) return;
    _tracks.removeAt(index);
    if (_currentTrackIndex == index) {
      _currentTrackIndex = null;
    } else if (_currentTrackIndex != null && _currentTrackIndex! > index) {
      _currentTrackIndex = _currentTrackIndex! - 1;
    }
    notifyListeners();
  }

  void setCurrentTrack(int? index) {
    if (index != null && (index < 0 || index >= _tracks.length)) return;
    _currentTrackIndex = index;
    _enabled = index != null;
    notifyListeners();
  }

  void toggleEnabled() {
    _enabled = !_enabled;
    notifyListeners();
  }

  void setDelay(double delay) {
    _delay = delay;
    notifyListeners();
  }

  void clear() {
    _tracks.clear();
    _currentTrackIndex = null;
    _enabled = false;
    _delay = 0;
    notifyListeners();
  }
}