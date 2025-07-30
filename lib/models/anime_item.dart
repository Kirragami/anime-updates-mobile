class AnimeItem {
  static int _counter = 0;
  
  final String id;
  final String title;
  final String downloadUrl;

  AnimeItem({
    required this.id,
    required this.title,
    required this.downloadUrl,
  });

  factory AnimeItem.fromJson(Map<String, dynamic> json) {
    // Create a unique ID using a static counter
    _counter++;
    final uniqueId = 'anime_${_counter}_${DateTime.now().millisecondsSinceEpoch}';
    
    return AnimeItem(
      id: json['id']?.toString() ?? uniqueId,
      title: json['title'] ?? '',
      downloadUrl: json['downloadlink'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'downloadUrl': downloadUrl,
    };
  }

  AnimeItem copyWith({
    String? id,
    String? title,
    String? downloadUrl,
  }) {
    return AnimeItem(
      id: id ?? this.id,
      title: title ?? this.title,
      downloadUrl: downloadUrl ?? this.downloadUrl,
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
    return 'AnimeItem(id: $id, title: $title, downloadUrl: $downloadUrl)';
  }
} 