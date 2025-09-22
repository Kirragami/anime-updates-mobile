class ActiveDownload {
  final String releaseId;
  final String fileName;
  final String showName;
  final String episode;
  final String sha1;
  final double progress;
  final int speed;
  final ActiveDownloadStatus status;

  const ActiveDownload({
    required this.releaseId,
    required this.fileName,
    required this.showName,
    required this.episode,
    required this.sha1,
    required this.progress,
    required this.speed,
    required this.status,
  });

  ActiveDownload copyWith({
    String? releaseId,
    String? fileName,
    String? showName,
    String? episode,
    String? sha1,
    double? progress,
    int? speed,
    ActiveDownloadStatus? status,
  }) {
    return ActiveDownload(
      releaseId: releaseId ?? this.releaseId,
      fileName: fileName ?? this.fileName,
      showName: showName ?? this.showName,
      episode: episode ?? this.episode,
      sha1: sha1 ?? this.sha1,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      status: status ?? this.status,
    );
  }

  factory ActiveDownload.fromMap(Map<String, dynamic> map) {
    return ActiveDownload(
      releaseId: map['releaseId'] as String,
      fileName: map['fileName'] as String,
      showName: map['showName'] as String,
      episode: map['episode'] as String,
      sha1: map['sha1'] as String,
      progress: (map['progress'] as num).toDouble(),
      speed: map['speed'] as int,
      status: _parseStatus(map['status'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'releaseId': releaseId,
      'fileName': fileName,
      'showName': showName,
      'episode': episode,
      'sha1': sha1,
      'progress': progress,
      'speed': speed,
      'status': status.name,
    };
  }

  static ActiveDownloadStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'downloading':
        return ActiveDownloadStatus.downloading;
      case 'paused':
        return ActiveDownloadStatus.paused;
      default:
        return ActiveDownloadStatus.downloading;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActiveDownload &&
        other.releaseId == releaseId &&
        other.fileName == fileName &&
        other.showName == showName &&
        other.episode == episode &&
        other.sha1 == sha1 &&
        other.progress == progress &&
        other.speed == speed &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      releaseId,
      fileName,
      showName,
      episode,
      sha1,
      progress,
      speed,
      status,
    );
  }

  @override
  String toString() {
    return 'ActiveDownload(releaseId: $releaseId, fileName: $fileName, progress: $progress%, status: $status)';
  }
}

enum ActiveDownloadStatus {
  downloading,
  paused,
}

extension ActiveDownloadStatusExtension on ActiveDownloadStatus {
  String get displayName {
    switch (this) {
      case ActiveDownloadStatus.downloading:
        return 'Downloading';
      case ActiveDownloadStatus.paused:
        return 'Paused';
    }
  }

  bool get isActive {
    return this == ActiveDownloadStatus.downloading;
  }
}
