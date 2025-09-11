import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'download_state.dart';

class AnimeItem {
  final String id;
  final String title;
  final String animeShowId;
  final String downloadUrl;
  final String episode;
  final DateTime releasedDate;
  final String fileName;
  final String imageUrl;
  final bool tracked;
  final DownloadState downloadState;
  final double progress;

  AnimeItem({
    required this.id,
    required this.title,
    required this.animeShowId,
    required this.downloadUrl,
    required this.episode,
    required this.releasedDate,
    required this.fileName,
    required this.imageUrl,
    required this.tracked,
    this.downloadState = DownloadState.notDownloaded,
    this.progress = 0.0,
  });

  factory AnimeItem.fromJson(Map<String, dynamic> json) {
    // Parse the releasedDate string to DateTime and convert from UTC to local time
    DateTime parseReleasedDate(String? dateString) {
      if (dateString == null) return DateTime.now().toLocal();
      try {
        // Parse as UTC and then convert to local time
        return DateTime.parse("${dateString}Z").toUtc().toLocal();
      } catch (e) {
        return DateTime.now().toLocal();
      }
    }
    
    // Parse bool values that might come as strings
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }
    
    // Debug logging for JSON structure
    if (kDebugMode) {
      print('Parsing JSON item: $json');
      print('Available keys: ${json.keys.toList()}');
    }
    
    return AnimeItem(
      id: json['releaseId']?.toString() ?? '',
      title: json['showTitle'] ?? '',
      animeShowId: json['animeShowId']?.toString() ?? '',
      downloadUrl: json['releaseDownloadLink'] ?? '',
      episode: json['episode'] ?? '',
      releasedDate: parseReleasedDate(json['releasedDate']),
      fileName: json['fileName'] ?? '',
      imageUrl: json['imgUrl'] ?? '',
      tracked: parseBool(json['tracked']),
      downloadState: DownloadState.notDownloaded,
      progress: 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'animeShowId': animeShowId,
      'downloadUrl': downloadUrl,
      'episode': episode,
      'releasedDate': releasedDate.toUtc().toIso8601String(),
      'imageUrl': imageUrl,
      'tracked': tracked,
      'downloadState': downloadState.toString(),
      'progress': progress,
    };
  }

  AnimeItem copyWith({
    String? id,
    String? title,
    String? animeShowId,
    String? downloadUrl,
    String? episode,
    DateTime? releasedDate,
    String? fileName,
    String? imageUrl,
    bool? tracked,
    DownloadState? downloadState,
    double? progress,
  }) {
    return AnimeItem(
      id: id ?? this.id,
      title: title ?? this.title,
      animeShowId: animeShowId ?? this.animeShowId,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      episode: episode ?? this.episode,
      releasedDate: releasedDate ?? this.releasedDate,
      fileName: fileName ?? this.fileName,
      imageUrl: imageUrl ?? this.imageUrl,
      tracked: tracked ?? this.tracked,
      downloadState: downloadState ?? this.downloadState,
      progress: progress ?? this.progress,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnimeItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AnimeItem(id: $id, title: $title, animeShowId: $animeShowId, downloadUrl: $downloadUrl, episode: $episode, releasedDate: $releasedDate, fileName: $fileName, imageUrl: $imageUrl, tracked: $tracked)';
  }

  /// Formats the releasedDate for display in the user's local time zone
  String formatReleasedDate([String pattern = 'yyyy-MM-dd HH:mm']) {
    try {
      return DateFormat(pattern).format(releasedDate);
    } catch (e) {
      return 'Invalid Date';
    }
  }
} 