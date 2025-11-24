import 'dart:io';

class MediaFile {
  final String path;
  final String name;
  final bool isVideo;
  final int size;
  final DateTime lastModified;

  MediaFile({
    required this.path,
    required this.name,
    required this.isVideo,
    required this.size,
    required this.lastModified,
  });

  factory MediaFile.fromFile(File file, bool isVideo) {
    final stat = file.statSync();
    return MediaFile(
      path: file.path,
      name: file.uri.pathSegments.last,
      isVideo: isVideo,
      size: stat.size,
      lastModified: stat.modified,
    );
  }

  String get extension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get displayName {
    // Remove extension from display name
    final lastDot = name.lastIndexOf('.');
    return lastDot > 0 ? name.substring(0, lastDot) : name;
  }
}
