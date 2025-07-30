import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/anime_item.dart';
import '../constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<List<AnimeItem>> fetchAnimeList() async {
    try {
      if (kDebugMode) {
        print('Making API call to: ${AppConstants.fullApiUrl}');
      }

      final response = await http.get(
        Uri.parse(AppConstants.fullApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'AnimeUpdates/1.0',
        },
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
        print('Response headers: ${response.headers}');
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        
        // Handle empty response
        if (responseBody.isEmpty) {
          if (kDebugMode) {
            print('Empty response received');
          }
          return [];
        }

        // Parse JSON response
        List<dynamic> jsonData;
        try {
          jsonData = jsonDecode(responseBody);
          if (kDebugMode) {
            print('Successfully parsed JSON: $jsonData');
          }
        } catch (e) {
          if (kDebugMode) {
            print('JSON parsing error: $e');
          }
          // If response is not a valid JSON array, try to handle it
          if (responseBody.startsWith('[')) {
            throw Exception('Invalid JSON format');
          } else {
            // If it's a single object, wrap it in an array
            final singleObject = jsonDecode(responseBody);
            jsonData = [singleObject];
          }
        }

        final animeList = jsonData
            .map((jsonItem) => AnimeItem.fromJson(jsonItem))
            .toList();

        if (kDebugMode) {
          print('Successfully created ${animeList.length} anime items');
        }

        return animeList;
      } else {
        if (kDebugMode) {
          print('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
          print('Response body: ${response.body}');
        }
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('API call error: $e');
        print('Error type: ${e.runtimeType}');
      }
      
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed host lookup')) {
        throw Exception('${AppConstants.networkError}\n\nDetails: $e');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('Request timeout. Please try again.\n\nDetails: $e');
      } else if (e.toString().contains('HandshakeException')) {
        throw Exception('SSL/TLS error. Please check your server configuration.\n\nDetails: $e');
      } else {
        throw Exception('Failed to fetch anime list: $e');
      }
    }
  }

  Future<bool> testConnection() async {
    try {
      if (kDebugMode) {
        print('Testing connection to: ${AppConstants.baseUrl}');
      }

      final response = await http.get(
        Uri.parse(AppConstants.baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'AnimeUpdates/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Connection test status: ${response.statusCode}');
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Connection test failed: $e');
      }
      return false;
    }
  }

  Future<bool> testAnimeEndpoint() async {
    try {
      if (kDebugMode) {
        print('Testing anime endpoint: ${AppConstants.fullApiUrl}');
      }

      final response = await http.get(
        Uri.parse(AppConstants.fullApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'AnimeUpdates/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Anime endpoint test status: ${response.statusCode}');
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Anime endpoint test failed: $e');
      }
      return false;
    }
  }
} 