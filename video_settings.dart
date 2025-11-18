import 'package:flutter/foundation.dart';

class VideoSettings extends ChangeNotifier {
  double _volume = 0.8;
  double _playbackRate = 1.0;
  String _aspectRatio = 'auto';
  bool _isFullscreen = false;
  Map<String, bool> _videoEffects = {
    'brightness': false,
    'contrast': false,
    'saturation': false,
    'hue': false,
  };
  Map<String, double> _videoEffectValues = {
    'brightness': 0.0,
    'contrast': 1.0,
    'saturation': 1.0,
    'hue': 0.0,
  };

  double get volume => _volume;
  double get playbackRate => _playbackRate;
  String get aspectRatio => _aspectRatio;
  bool get isFullscreen => _isFullscreen;
  Map<String, bool> get videoEffects => Map.unmodifiable(_videoEffects);
  Map<String, double> get videoEffectValues => Map.unmodifiable(_videoEffectValues);

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setPlaybackRate(double rate) {
    _playbackRate = rate;
    notifyListeners();
  }

  void setAspectRatio(String ratio) {
    _aspectRatio = ratio;
    notifyListeners();
  }

  void toggleFullscreen() {
    _isFullscreen = !_isFullscreen;
    notifyListeners();
  }

  void toggleVideoEffect(String effect) {
    if (_videoEffects.containsKey(effect)) {
      _videoEffects[effect] = !_videoEffects[effect]!;
      notifyListeners();
    }
  }

  void setVideoEffectValue(String effect, double value) {
    if (_videoEffectValues.containsKey(effect)) {
      _videoEffectValues[effect] = value;
      notifyListeners();
    }
  }

  String get cssFilter {
    if (!_videoEffects.values.any((enabled) => enabled)) return '';
    
    List<String> filters = [];
    if (_videoEffects['brightness']!) {
      filters.add('brightness(${100 + (_videoEffectValues['brightness']! * 100)}%)');
    }
    if (_videoEffects['contrast']!) {
      filters.add('contrast(${_videoEffectValues['contrast']! * 100}%)');
    }
    if (_videoEffects['saturation']!) {
      filters.add('saturate(${_videoEffectValues['saturation']! * 100}%)');
    }
    if (_videoEffects['hue']!) {
      filters.add('hue-rotate(${_videoEffectValues['hue']! * 360}deg)');
    }
    return filters.join(' ');
  }
}