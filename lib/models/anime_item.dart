import 'package:flutter/foundation.dart';

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
  });

  factory AnimeItem.fromJson(Map<String, dynamic> json) {
    // Parse the releasedDate string to DateTime
    DateTime parseReleasedDate(String? dateString) {
      if (dateString == null) return DateTime.now();
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        return DateTime.now();
      }
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
      tracked: json['tracked'] ?? false
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'animeShowId': animeShowId,
      'downloadUrl': downloadUrl,
      'episode': episode,
      'releasedDate': releasedDate.toIso8601String(),
      'imageUrl': imageUrl,
      'tracked': tracked,
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
} 