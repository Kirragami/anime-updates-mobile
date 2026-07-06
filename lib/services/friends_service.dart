import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../models/tomodachi.dart';
import 'dio_client.dart';

class FriendsService {
  static final FriendsService _instance = FriendsService._internal();
  factory FriendsService() => _instance;
  FriendsService._internal();

  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<List<Tomodachi>> fetchFriends() async {
    try {
      final response = await dioClient
          .get(
            '${AppConstants.baseUrl}${AppConstants.friendsEndpoint}',
            options: Options(headers: _headers),
          )
          .timeout(const Duration(seconds: 30));

      final body = _asMap(response.data);
      if (body == null) {
        throw Exception('Unexpected response from server');
      }

      if (!_isSuccess(body['success'])) {
        throw Exception(
          body['message']?.toString() ?? 'Failed to load tomodachi list',
        );
      }

      final data = body['data'];
      if (data == null) {
        return [];
      }
      if (data is! List) {
        return [];
      }

      return data
          .whereType<Map>()
          .map((item) => Tomodachi.fromJson(Map<String, dynamic>.from(item)))
          .where((t) => !t.isDeclined)
          .toList();
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<Map<String, dynamic>> sendRequest(String username) {
    return _postWithUsername(AppConstants.friendsRequestEndpoint, username);
  }

  Future<Map<String, dynamic>> removeFriend(String username) {
    return _postWithUsername(AppConstants.friendsRemoveEndpoint, username);
  }

  Future<Map<String, dynamic>> declineRequest(String username) {
    return _postWithUsername(AppConstants.friendsDeclineEndpoint, username);
  }

  Future<Map<String, dynamic>> acceptRequest(String username) {
    return _postWithUsername(AppConstants.friendsAcceptEndpoint, username);
  }

  Future<Map<String, dynamic>> _postWithUsername(
    String endpoint,
    String username,
  ) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) {
      return {
        'success': false,
        'message': 'Username is required',
        'code': 'username_required',
      };
    }

    try {
      final response = await dioClient
          .post(
            '${AppConstants.baseUrl}$endpoint',
            data: jsonEncode({'username': trimmedUsername}),
            options: Options(headers: _headers),
          )
          .timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('Friends POST $endpoint -> ${response.statusCode}: ${response.data}');
      }

      return _parseMutationSuccess(response);
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Friends API error ($endpoint): $e');
        print('Friends API error body: ${e.response?.data}');
      }
      return _parseMutationError(e);
    } catch (e) {
      return {
        'success': false,
        'message': 'Something went wrong',
        'code': null,
      };
    }
  }

  Map<String, dynamic> _parseMutationSuccess(Response<dynamic> response) {
    final body = _asMap(response.data);
    if (body != null && _isSuccess(body['success'])) {
      return {
        'success': true,
        'message': body['message']?.toString() ?? '',
        'code': body['code'],
      };
    }

    if (body != null) {
      return _errorResult(body, response.statusCode);
    }

    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) {
      return {
        'success': true,
        'message': 'Success',
        'code': status,
      };
    }

    return {
      'success': false,
      'message': 'Unexpected response from server',
      'code': status,
    };
  }

  Map<String, dynamic> _parseMutationError(DioException e) {
    final response = e.response;
    final body = _asMap(response?.data);
    if (body != null) {
      return _errorResult(body, response?.statusCode);
    }

    if (response?.statusCode == 401) {
      return {
        'success': false,
        'message': 'Please log in again',
        'code': 401,
      };
    }

    return {
      'success': false,
      'message': 'Network error. Please try again.',
      'code': null,
    };
  }

  Map<String, dynamic> _errorResult(
    Map<String, dynamic> body,
    int? statusCode,
  ) {
    return {
      'success': false,
      'message': body['message']?.toString() ??
          body['error']?.toString() ??
          'Request failed',
      'code': body['code'] ?? statusCode,
    };
  }

  String _messageFromDio(DioException e) {
    final body = _asMap(e.response?.data);
    if (body != null) {
      return body['message']?.toString() ??
          body['error']?.toString() ??
          'Failed to load tomodachi list';
    }
    if (e.response?.statusCode == 401) {
      return 'Please log in again';
    }
    return 'Network error. Please try again.';
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
      return null;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  bool _isSuccess(dynamic value) {
    if (value == true) {
      return true;
    }
    if (value is String && value.toLowerCase() == 'true') {
      return true;
    }
    return false;
  }
}
