class Tomodachi {
  final int id;
  final String username;
  final String status;
  final bool isSender;

  const Tomodachi({
    required this.id,
    required this.username,
    required this.status,
    required this.isSender,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
  bool get isDeclined => status.toUpperCase() == 'DECLINED';

  factory Tomodachi.fromJson(Map<String, dynamic> json) {
    return Tomodachi(
      id: _parseId(json['id']),
      username: (json['username']?.toString() ?? '').trim(),
      status: json['status']?.toString() ?? '',
      isSender: _parseIsSender(json),
    );
  }

  static int _parseId(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _parseIsSender(Map<String, dynamic> json) {
    final value = json['isSender'] ?? json['sender'];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }
}
