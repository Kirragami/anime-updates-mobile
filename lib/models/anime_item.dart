import 'package:flutter/foundation.dart';

class AnimeItem {
  static int _counter = 0;
  
  final String id;
  final String title;
  final String downloadUrl;
  final String episode;
  final DateTime releasedDate;
  final String fileName;
  final String imageUrl;

  AnimeItem({
    required this.id,
    required this.title,
    required this.downloadUrl,
    required this.episode,
    required this.releasedDate,
    required this.fileName,
    required this.imageUrl,
  });

  factory AnimeItem.fromJson(Map<String, dynamic> json) {
    // Create a unique ID using a static counter
    _counter++;
    final uniqueId = 'anime_${_counter}_${DateTime.now().millisecondsSinceEpoch}';
    
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
      id: json['releaseId']?.toString() ?? uniqueId,
      title: json['showTitle'] ?? '',
      downloadUrl: json['releaseDownloadLink'] ?? '',
      episode: json['episode'] ?? '',
      releasedDate: parseReleasedDate(json['releasedDate']),
      fileName: json['fileName'] ?? '',
      imageUrl: json['imgUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'downloadUrl': downloadUrl,
      'episode': episode,
      'releasedDate': releasedDate.toIso8601String(),
      'imageUrl': imageUrl,
    };
  }

  AnimeItem copyWith({
    String? id,
    String? title,
    String? downloadUrl,
    String? episode,
    DateTime? releasedDate,
    String? fileName,
    String? imageUrl,
  }) {
    return AnimeItem(
      id: id ?? this.id,
      title: title ?? this.title,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      episode: episode ?? this.episode,
      releasedDate: releasedDate ?? this.releasedDate,
      fileName: fileName ?? this.fileName,
      imageUrl: imageUrl ?? this.imageUrl,
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
    return 'AnimeItem(id: $id, title: $title, downloadUrl: $downloadUrl, episode: $episode, releasedDate: $releasedDate, fileName: $fileName, imageUrl: $imageUrl)';
  }
} 