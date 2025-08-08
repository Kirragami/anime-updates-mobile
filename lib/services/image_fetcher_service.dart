import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ImageFetcherService {
  static const String _baseUrl = 'https://api.jikan.moe/v4/anime';
  
  /// Fetches an image URL for the given anime title
  /// Returns the image URL if found, null otherwise
  static Future<String?> fetchAnimeImage(String title) async {
    return _fetchAnimeImageWithRetry(title, 0);
  }
  
  /// Fetches an image URL with retry logic
  static Future<String?> _fetchAnimeImageWithRetry(String title, int retryCount) async {
    try {
      // Add a small delay to prevent overwhelming the API
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Encode the title for URL parameter
      final encodedTitle = Uri.encodeComponent(title);
      final url = Uri.parse('$_baseUrl?q=$encodedTitle');
      
      if (kDebugMode) {
        print('Fetching image for: $title (attempt ${retryCount + 1})');
        print('URL: $url');
      }
      
      final response = await http.get(url);
      
      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if we have titles in the response
        if (data['data'] != null && data['data'].isNotEmpty) {
          final firstTitle = data['data'][0];
          
          // Check if the title has a primary image
          if (firstTitle['images'] != null && 
              firstTitle['images']['jpg'] != null) {
            final imageUrl = firstTitle['images']['jpg']['large_image_url'];
            if (kDebugMode) {
              print('Found image URL: $imageUrl');
            }
            return imageUrl;
          }
        }
        
        if (kDebugMode) {
          print('No image found for: $title');
        }
      } else if (response.statusCode == 429) {
        if (kDebugMode) {
          print('Rate limited (429) for: $title - Too many requests');
        }
        
        // Retry up to 2 more times with increasing delays
        if (retryCount < 10) {
          final delay = 1000; // 2s, 4s delays
          if (kDebugMode) {
            print('Retrying in ${delay}ms (attempt ${retryCount + 1})');
          }
          await Future.delayed(Duration(milliseconds: delay));
          return _fetchAnimeImageWithRetry(title, retryCount + 1);
        } else {
          if (kDebugMode) {
            print('Max retries reached for: $title');
          }
        }
      } else {
        if (kDebugMode) {
          print('HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching anime image for $title: $e');
      }
      
      // Retry on network errors too
      if (retryCount < 2) {
        final delay = (retryCount + 1) * 2000; // 2s, 4s delays
        if (kDebugMode) {
          print('Retrying after error in ${delay}ms (attempt ${retryCount + 1})');
        }
        await Future.delayed(Duration(milliseconds: delay));
        return _fetchAnimeImageWithRetry(title, retryCount + 1);
      }
      
      return null;
    }
  }
  
  /// Fetches multiple anime images for a list of titles
  /// Returns a map of title to image URL
  static Future<Map<String, String>> fetchAnimeImages(List<String> titles) async {
    final Map<String, String> imageUrls = {};
    
    for (final title in titles) {
      final imageUrl = await fetchAnimeImage(title);
      if (imageUrl != null) {
        imageUrls[title] = imageUrl;
      }
    }
    
    return imageUrls;
  }
} 