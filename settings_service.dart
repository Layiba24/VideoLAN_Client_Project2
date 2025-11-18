import 'dart:convert';
import 'dart:html' as html;
import '../models/media_item.dart';

class SettingsService {
  static const String _volumeKey = 'vlc_volume';
  static const String _playbackRateKey = 'vlc_playback_rate';
  static const String _aspectRatioKey = 'vlc_aspect_ratio';
  static const String _recentFilesKey = 'vlc_recent_files';
  static const String _videoEffectsKey = 'vlc_video_effects';
  
  static double getVolume() {
    return double.tryParse(
      html.window.localStorage[_volumeKey] ?? '0.8'
    ) ?? 0.8;
  }
  
  static void setVolume(double volume) {
    html.window.localStorage[_volumeKey] = volume.toString();
  }
  
  static double getPlaybackRate() {
    return double.tryParse(
      html.window.localStorage[_playbackRateKey] ?? '1.0'
    ) ?? 1.0;
  }
  
  static void setPlaybackRate(double rate) {
    html.window.localStorage[_playbackRateKey] = rate.toString();
  }
  
  static String getAspectRatio() {
    return html.window.localStorage[_aspectRatioKey] ?? 'auto';
  }
  
  static void setAspectRatio(String ratio) {
    html.window.localStorage[_aspectRatioKey] = ratio;
  }
  
  static List<MediaItem> getRecentFiles() {
    try {
      final jsonStr = html.window.localStorage[_recentFilesKey];
      if (jsonStr == null) return [];
      
      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList.map((item) => MediaItem(
        title: item['title'],
        url: item['url'],
        addedAt: DateTime.parse(item['addedAt']),
        metadata: item['metadata'],
      )).toList();
    } catch (e) {
      print('Error loading recent files: $e');
      return [];
    }
  }
  
  static void addRecentFile(MediaItem item) {
    try {
      var recentFiles = getRecentFiles();
      recentFiles.removeWhere((file) => file.url == item.url);
      recentFiles.insert(0, item);
      
      // Keep only last 10 items
      if (recentFiles.length > 10) {
        recentFiles = recentFiles.sublist(0, 10);
      }
      
      final jsonList = recentFiles.map((file) => {
        'title': file.title,
        'url': file.url,
        'addedAt': file.addedAt.toIso8601String(),
        'metadata': file.metadata,
      }).toList();
      
      html.window.localStorage[_recentFilesKey] = json.encode(jsonList);
    } catch (e) {
      print('Error saving recent file: $e');
    }
  }
  
  static Map<String, dynamic> getVideoEffects() {
    try {
      final jsonStr = html.window.localStorage[_videoEffectsKey];
      if (jsonStr == null) return {};
      return json.decode(jsonStr);
    } catch (e) {
      print('Error loading video effects: $e');
      return {};
    }
  }
  
  static void saveVideoEffects(Map<String, dynamic> effects) {
    try {
      html.window.localStorage[_videoEffectsKey] = json.encode(effects);
    } catch (e) {
      print('Error saving video effects: $e');
    }
  }
  
  static void clearAll() {
    html.window.localStorage.remove(_volumeKey);
    html.window.localStorage.remove(_playbackRateKey);
    html.window.localStorage.remove(_aspectRatioKey);
    html.window.localStorage.remove(_recentFilesKey);
    html.window.localStorage.remove(_videoEffectsKey);
  }
}