import 'package:flutter/foundation.dart';

@immutable
class MediaItem {
  final String title;
  final String url;
  final String? filePath;
  final DateTime addedAt;
  final Map<String, dynamic>? metadata;

  MediaItem({
    required this.title,
    required this.url,
    this.filePath,
    DateTime? addedAt,
    this.metadata,
  }) : addedAt = addedAt ?? DateTime.now();
}