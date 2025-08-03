import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ImageFetcherService {
  static const String _baseUrl = 'https://api.jikan.moe/v4/anime';
  
  /// Fetches an image URL for the given anime title
  /// Returns the image URL if found, null otherwise
  static Future<String?> fetchAnimeImage(String title) async {
    try {
      // Encode the title for URL parameter
      final encodedTitle = Uri.encodeComponent(title);
      final url = Uri.parse('$_baseUrl?q=$encodedTitle');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if we have titles in the response
        if (data['data'] != null && data['data'].isNotEmpty) {
          final firstTitle = data['data'][0];
          
          // Check if the title has a primary image
          if (firstTitle['images'] != null && 
              firstTitle['images']['jpg'] != null) {
            return firstTitle['images']['jpg']['image_url'];
          }
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching anime image: $e');
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