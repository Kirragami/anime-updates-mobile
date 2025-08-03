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
        print('Response body length: ${response.body.length}');
        print('Response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
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
          final Map<String, dynamic> responseJson = jsonDecode(responseBody);
          if (kDebugMode) {
            print('Successfully parsed JSON: $responseJson');
          }
          
          // Handle the new response format: { content: [data] }
          if (responseJson.containsKey('content')) {
            jsonData = responseJson['content'] as List<dynamic>;
            if (kDebugMode) {
              print('Found content array with ${jsonData.length} items');
            }
          } else if (responseJson.containsKey('data')) {
            // Handle alternative format: { data: [data] }
            jsonData = responseJson['data'] as List<dynamic>;
            if (kDebugMode) {
              print('Found data array with ${jsonData.length} items');
            }
          } else if (responseJson.containsKey('items')) {
            // Handle alternative format: { items: [data] }
            jsonData = responseJson['items'] as List<dynamic>;
            if (kDebugMode) {
              print('Found items array with ${jsonData.length} items');
            }
          } else {
            // Fallback to direct array format
            jsonData = responseJson as List<dynamic>;
            if (kDebugMode) {
              print('Using direct array format with ${jsonData.length} items');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('JSON parsing error: $e');
          }
          // Try to parse as direct array if the object format fails
          try {
            jsonData = jsonDecode(responseBody) as List<dynamic>;
            if (kDebugMode) {
              print('Parsed as direct array with ${jsonData.length} items');
            }
          } catch (e2) {
            if (kDebugMode) {
              print('Failed to parse as array: $e2');
            }
            throw Exception('Invalid JSON format: $e');
          }
        }

        // Validate that jsonData is a list (jsonData is already List<dynamic> from parsing)
        if (jsonData.isEmpty) {
          if (kDebugMode) {
            print('Empty data array received');
          }
        }

        final animeList = jsonData
            .map((jsonItem) => AnimeItem.fromJson(jsonItem))
            .toList();

        if (kDebugMode) {
          print('Successfully created ${animeList.length} anime items');
          if (animeList.isNotEmpty) {
            print('First item: ${animeList.first.title}');
          }
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