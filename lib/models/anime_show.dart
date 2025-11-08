import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AnimeShow {
  final String id;
  final String title;
  final String imageUrl;
  final DateTime latestReleasedTime;

  AnimeShow({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.latestReleasedTime,
  });

  factory AnimeShow.fromJson(Map<String, dynamic> json) {
    DateTime parseLatestReleasedTime(String? dateString) {
      if (dateString == null) return DateTime.now().toLocal();
      try {
        return DateTime.parse("${dateString}Z").toUtc().toLocal();
      } catch (e) {
        return DateTime.now().toLocal();
      }
    }

    return AnimeShow(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      imageUrl: json['imageUrl'] ?? json['imgUrl'] ?? '',
      latestReleasedTime: parseLatestReleasedTime(json['latestReleasedTime'] ?? json['releasedDate']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'latestReleasedTime': latestReleasedTime.toUtc().toIso8601String(),
    };
  }

  AnimeShow copyWith({
    String? id,
    String? title,
    String? imageUrl,
    DateTime? latestReleasedTime,
  }) {
    return AnimeShow(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      latestReleasedTime: latestReleasedTime ?? this.latestReleasedTime,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnimeShow && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AnimeShow(id: $id, title: $title, imageUrl: $imageUrl, latestReleasedTime: $latestReleasedTime)';
  }

  String formatLatestReleasedTime([String pattern = 'yyyy-MM-dd HH:mm']) {
    try {
      return DateFormat(pattern).format(latestReleasedTime);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  /// Calculate if this show is new based on how recent the latest release is
  bool isNew() {
    final now = DateTime.now();
    final difference = now.difference(latestReleasedTime);
    return difference.inDays < 1; // Within last 24 hours
  }

  /// Get time ago string for display
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(latestReleasedTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }
}