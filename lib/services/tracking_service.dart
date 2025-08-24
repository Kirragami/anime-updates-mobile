import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import 'dio_client.dart';

class TrackingService {
  static final TrackingService _instance = TrackingService._internal();
  factory TrackingService() => _instance;
  TrackingService._internal();

  /// Track an anime show
  Future<Map<String, dynamic>> trackAnime(String animeShowId) async {
    try {
      if (kDebugMode) {
        print('Tracking anime with ID: $animeShowId');
      }

      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.trackShowEndpoint}/$animeShowId');

      final response = await dioClient.post(
        uri.toString(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('Track anime response status: ${response.statusCode}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': 'Anime tracked successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to track anime',
          'error': 'HTTP ${response.statusCode}: ${response.statusMessage}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Track anime error: $e');
      }
      
      return {
        'success': false,
        'message': 'Failed to track anime',
        'error': e.toString(),
      };
    }
  }

  /// Untrack an anime show
  Future<Map<String, dynamic>> untrackAnime(String animeShowId) async {
    try {
      if (kDebugMode) {
        print('Untracking anime with ID: $animeShowId');
      }

      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.untrackShowEndpoint}/$animeShowId');

      final response = await dioClient.post(
        uri.toString(),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('Untrack anime response status: ${response.statusCode}');
      }

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Anime untracked successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to untrack anime',
          'error': 'HTTP ${response.statusCode}: ${response.statusMessage}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Untrack anime error: $e');
      }
      
      return {
        'success': false,
        'message': 'Failed to untrack anime',
        'error': e.toString(),
      };
    }
  }
}