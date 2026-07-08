import 'dart:convert';

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../models/watch_party_models.dart';
import 'dio_client.dart';

class WatchPartyService {
  static final WatchPartyService _instance = WatchPartyService._internal();
  factory WatchPartyService() => _instance;
  WatchPartyService._internal();

  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<PartyInviteResult> inviteFriend(String friendUsername) async {
    final response = await dioClient
        .post(
          '${AppConstants.baseUrl}${AppConstants.partyInviteEndpoint}',
          data: jsonEncode({'friendUsername': friendUsername}),
          options: Options(headers: _headers),
        )
        .timeout(const Duration(seconds: 30));

    final body = _asMap(response.data);
    if (body == null || !_isSuccess(body['success'])) {
      throw Exception(body?['message']?.toString() ?? 'Failed to send invite');
    }

    final data = body['data'];
    if (data is! Map) {
      throw Exception('Unexpected invite response');
    }

    return PartyInviteResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> acceptInvite({
    required String partyId,
    required String token,
  }) async {
    await _postPartyAction(
      partyId: partyId,
      pathSuffix: 'accept',
      body: {'token': token},
      fallbackMessage: 'Failed to join watch party',
    );
  }

  Future<void> declineInvite({
    required String partyId,
    required String token,
  }) async {
    await _postPartyAction(
      partyId: partyId,
      pathSuffix: 'decline',
      body: {'token': token},
      fallbackMessage: 'Failed to decline invite',
    );
  }

  Future<PartyState> getPartyState(String partyId) async {
    try {
      final response = await dioClient
          .get(
            '${AppConstants.baseUrl}${AppConstants.partyEndpoint}/$partyId',
            options: Options(headers: _headers),
          )
          .timeout(const Duration(seconds: 30));

      final body = _asMap(response.data);
      if (body == null || !_isSuccess(body['success'])) {
        throw Exception(
          body?['message']?.toString() ?? 'Failed to load party state',
        );
      }

      final data = body['data'];
      if (data is! Map) {
        throw Exception('Unexpected party state response');
      }

      return PartyState.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      final parsed = _asMap(e.response?.data);
      final message = parsed?['message']?.toString();
      if (message != null && message.isNotEmpty) {
        throw Exception(message);
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Watch party not found.');
      }
      rethrow;
    }
  }

  Future<void> _postPartyAction({
    required String partyId,
    required String pathSuffix,
    required Map<String, dynamic> body,
    required String fallbackMessage,
  }) async {
    try {
      final response = await dioClient
          .post(
            '${AppConstants.baseUrl}${AppConstants.partyEndpoint}/$partyId/$pathSuffix',
            data: jsonEncode(body),
            options: Options(headers: _headers),
          )
          .timeout(const Duration(seconds: 30));

      final parsed = _asMap(response.data);
      if (parsed != null && !_isSuccess(parsed['success'])) {
        throw Exception(parsed['message']?.toString() ?? fallbackMessage);
      }
    } on DioException catch (e) {
      final parsed = _asMap(e.response?.data);
      throw Exception(parsed?['message']?.toString() ?? fallbackMessage);
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return null;
  }

  bool _isSuccess(dynamic value) {
    if (value == true) return true;
    if (value is String && value.toLowerCase() == 'true') return true;
    return false;
  }
}
