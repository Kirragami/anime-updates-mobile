import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/anime_item.dart';
import '../constants/app_constants.dart';
import 'auth_service.dart';

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

          // New format: { success, message, code, data: { content: [...] } }
          if (responseJson.containsKey('data')) {
            final dynamic dataNode = responseJson['data'];
            if (dataNode is Map<String, dynamic>) {
              if (dataNode.containsKey('content') && dataNode['content'] is List) {
                jsonData = dataNode['content'] as List<dynamic>;
                if (kDebugMode) {
                  print('Found data.content array with ${jsonData.length} items');
                }
              } else if (dataNode.containsKey('items') && dataNode['items'] is List) {
                jsonData = dataNode['items'] as List<dynamic>;
                if (kDebugMode) {
                  print('Found data.items array with ${jsonData.length} items');
                }
              } else {
                // Try to find the first list within data map
                final dynamic firstList = (dataNode.values).firstWhere(
                  (v) => v is List,
                  orElse: () => <dynamic>[],
                );
                jsonData = (firstList is List) ? firstList as List<dynamic> : <dynamic>[];
                if (kDebugMode) {
                  print('Used first list in data map, length: ${jsonData.length}');
                }
              }
            } else if (dataNode is List) {
              jsonData = dataNode as List<dynamic>;
              if (kDebugMode) {
                print('Found data as array with ${jsonData.length} items');
              }
            } else {
              jsonData = <dynamic>[];
            }
          } else if (responseJson.containsKey('content')) {
            jsonData = responseJson['content'] as List<dynamic>;
            if (kDebugMode) {
              print('Found top-level content array with ${jsonData.length} items');
            }
          } else if (responseJson.containsKey('items')) {
            jsonData = responseJson['items'] as List<dynamic>;
            if (kDebugMode) {
              print('Found top-level items array with ${jsonData.length} items');
            }
          } else if (responseJson is Map<String, dynamic>) {
            // Fallback: find first list in the map
            final dynamic firstList = (responseJson.values).firstWhere(
              (v) => v is List,
              orElse: () => <dynamic>[],
            );
            jsonData = (firstList is List) ? firstList as List<dynamic> : <dynamic>[];
            if (kDebugMode) {
              print('Used first list in response map, length: ${jsonData.length}');
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
        if (decoded.containsKey('data')) {
          final dynamic dataNode = decoded['data'];
          if (dataNode is Map<String, dynamic>) {
            if (dataNode.containsKey('content') && dataNode['content'] is List) {
              jsonData = dataNode['content'] as List<dynamic>;
            } else if (dataNode.containsKey('items') && dataNode['items'] is List) {
              jsonData = dataNode['items'] as List<dynamic>;
            } else {
              jsonData = (dataNode.values).firstWhere(
                (v) => v is List,
                orElse: () => <dynamic>[],
              ) as List<dynamic>;
            }

            // Pagination flags nested in data
            if (dataNode.containsKey('last')) {
              last = dataNode['last'] == true;
            } else if (dataNode.containsKey('page') && dataNode['page'] is Map) {
              final pageObj = dataNode['page'] as Map;
              if (pageObj.containsKey('totalPages') && pageObj.containsKey('number')) {
                final totalPages = int.tryParse(pageObj['totalPages'].toString()) ?? 1;
                final current = int.tryParse(pageObj['number'].toString()) ?? (page - 1);
                last = (current + 1) >= totalPages;
              }
            }
          } else if (dataNode is List) {
            jsonData = dataNode as List<dynamic>;
          } else {
            jsonData = <dynamic>[];
          }
        } else if (decoded.containsKey('content')) {
          jsonData = decoded['content'] as List<dynamic>;
        } else if (decoded.containsKey('items')) {
          jsonData = decoded['items'] as List<dynamic>;
        } else {
          // Fallback: if server returns array at root unexpectedly
          jsonData = (decoded as Map<String, dynamic>).values.firstWhere(
            (v) => v is List,
            orElse: () => <dynamic>[],
          ) as List<dynamic>;
        }

        // Common pagination flags at top-level
        if (!last) {
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

  /// Fetch a paginated page of tracked releases (requires auth)
  Future<Map<String, dynamic>> fetchTrackedReleasesPage({required int page, required int size}) async {
    try {
      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.trackedReleasesEndpoint}').replace(
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
        },
      );

      if (kDebugMode) {
        print('Making paginated tracked releases API call to: $uri');
      }

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'AnimeUpdates/1.0',
      };

      final token = AuthService.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        throw Exception('Unauthorized. Please log in.');
      }
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
        if (decoded.containsKey('data')) {
          final dynamic dataNode = decoded['data'];
          if (dataNode is Map<String, dynamic>) {
            if (dataNode.containsKey('content') && dataNode['content'] is List) {
              jsonData = dataNode['content'] as List<dynamic>;
            } else if (dataNode.containsKey('items') && dataNode['items'] is List) {
              jsonData = dataNode['items'] as List<dynamic>;
            } else {
              jsonData = (dataNode.values).firstWhere(
                (v) => v is List,
                orElse: () => <dynamic>[],
              ) as List<dynamic>;
            }

            if (dataNode.containsKey('last')) {
              last = dataNode['last'] == true;
            } else if (dataNode.containsKey('page') && dataNode['page'] is Map) {
              final pageObj = dataNode['page'] as Map;
              if (pageObj.containsKey('totalPages') && pageObj.containsKey('number')) {
                final totalPages = int.tryParse(pageObj['totalPages'].toString()) ?? 1;
                final current = int.tryParse(pageObj['number'].toString()) ?? (page - 1);
                last = (current + 1) >= totalPages;
              }
            }
          } else if (dataNode is List) {
            jsonData = dataNode as List<dynamic>;
          } else {
            jsonData = <dynamic>[];
          }
        } else if (decoded.containsKey('content')) {
          jsonData = decoded['content'] as List<dynamic>;
        } else if (decoded.containsKey('items')) {
          jsonData = decoded['items'] as List<dynamic>;
        } else {
          jsonData = (decoded as Map<String, dynamic>).values.firstWhere(
            (v) => v is List,
            orElse: () => <dynamic>[],
          ) as List<dynamic>;
        }

        if (!last) {
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
        }
      } else if (decoded is List) {
        jsonData = decoded as List<dynamic>;
      } else {
        jsonData = <dynamic>[];
      }

      final items = jsonData.map((e) => AnimeItem.fromJson(e)).toList();

      if (!last) {
        last = items.length < size;
      }

      return {
        'items': items,
        'last': last,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Tracked releases API call error: $e');
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

  /// Track an anime show by sending a POST request to the tracking endpoint
  Future<Map<String, dynamic>> trackAnime({
    required String animeShowId,
    String? accessToken,
  }) async {
    try {
      if (kDebugMode) {
        print('Tracking anime with ID: $animeShowId');
      }

      // TODO: Replace with actual tracking endpoint
      final uri = Uri.parse('${AppConstants.baseUrl}/api/anime/track');
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'AnimeUpdates/1.0',
      };

      // Add authorization header if token is provided
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'animeShowId': animeShowId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (kDebugMode) {
        print('Track anime response status: ${response.statusCode}');
        print('Track anime response body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Anime tracked successfully',
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to track anime',
          'error': 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
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
} 