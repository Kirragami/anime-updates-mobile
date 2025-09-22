class CompletedDownload {
  final String releaseId;
  final String fileName;
  final String showName;
  final String episode;

  const CompletedDownload({
    required this.releaseId,
    required this.fileName,
    required this.showName,
    required this.episode,
  });

  CompletedDownload copyWith({
    String? releaseId,
    String? fileName,
    String? showName,
    String? episode,
  }) {
    return CompletedDownload(
      releaseId: releaseId ?? this.releaseId,
      fileName: fileName ?? this.fileName,
      showName: showName ?? this.showName,
      episode: episode ?? this.episode,
    );
  }

  factory CompletedDownload.fromMap(Map<String, dynamic> map) {
    return CompletedDownload(
      releaseId: map['releaseId'] as String,
      fileName: map['fileName'] as String,
      showName: map['showName'] as String,
      episode: map['episode'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'releaseId': releaseId,
      'fileName': fileName,
      'showName': showName,
      'episode': episode,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CompletedDownload &&
        other.releaseId == releaseId &&
        other.fileName == fileName &&
        other.showName == showName &&
        other.episode == episode;
  }

  @override
  int get hashCode {
    return Object.hash(
      releaseId,
      fileName,
      showName,
      episode,
    );
  }

  @override
  String toString() {
    return 'CompletedDownload(releaseId: $releaseId, fileName: $fileName, showName: $showName, episode: $episode)';
  }
}
