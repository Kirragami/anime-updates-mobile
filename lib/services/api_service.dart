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

  /// Fetch a paginated page of anime items
  Future<Map<String, dynamic>> fetchAnimePage({required int page, required int size}) async {
    try {
      final uri = Uri.parse(AppConstants.fullApiUrl).replace(
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      if (kDebugMode) {
        print('Making paginated API call to: $uri');
      }

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'AnimeUpdates/1.0',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final String responseBody = response.body;
      if (responseBody.isEmpty) {
        return {
          'items': <AnimeItem>[],
          'last': true,
        };
      }

      final decoded = jsonDecode(responseBody);
      List<dynamic> jsonData;
      bool last = false;

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('content')) {
          jsonData = decoded['content'] as List<dynamic>;
        } else if (decoded.containsKey('data')) {
          jsonData = decoded['data'] as List<dynamic>;
        } else if (decoded.containsKey('items')) {
          jsonData = decoded['items'] as List<dynamic>;
        } else {
          // Fallback: if server returns array at root unexpectedly
          jsonData = (decoded as Map<String, dynamic>).values.firstWhere(
            (v) => v is List,
            orElse: () => <dynamic>[],
          ) as List<dynamic>;
        }

        // Common pagination flags in Spring-like APIs
        if (decoded.containsKey('last')) {
          last = decoded['last'] == true;
        } else if (decoded.containsKey('page') && decoded['page'] is Map) {
          final pageObj = decoded['page'] as Map;
          if (pageObj.containsKey('totalPages') && pageObj.containsKey('number')) {
            final totalPages = int.tryParse(pageObj['totalPages'].toString()) ?? 1;
            final current = int.tryParse(pageObj['number'].toString()) ?? (page - 1);
            last = (current + 1) >= totalPages;
          }
        }
      } else if (decoded is List) {
        jsonData = decoded as List<dynamic>;
      } else {
        jsonData = <dynamic>[];
      }

      final items = jsonData.map((e) => AnimeItem.fromJson(e)).toList();

      // Fallback last-page heuristic
      if (!last) {
        last = items.length < size;
      }

      return {
        'items': items,
        'last': last,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Paginated API call error: $e');
      }
      rethrow;
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