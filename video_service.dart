import 'dart:html' as html;

class VideoMetadataService {
  static Future<Map<String, dynamic>> getVideoMetadata(html.File file) async {
    final video = html.VideoElement();
    final url = html.Url.createObjectUrlFromBlob(file);
    video.src = url;
    
    try {
      await video.onLoadedMetadata.first;
      return {
        'duration': video.duration,
        'width': video.videoWidth,
        'height': video.videoHeight,
        'size': file.size,
      };
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}

class FileValidator {
  static bool isVideoFile(String fileName) {
    final validExtensions = [
      '.mp4', '.mkv', '.avi', '.mov',
      '.wmv', '.flv', '.webm', '.m4v',
      '.3gp', '.mpg', '.mpeg', '.m2v',
    ];
    return validExtensions.any((ext) => fileName.toLowerCase().endsWith(ext));
  }
}