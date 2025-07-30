import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageFetcherService {
  static const String _baseUrl = 'https://api.imdbapi.dev/search/titles';
  
  /// Fetches an image URL for the given anime title
  /// Returns the image URL if found, null otherwise
  static Future<String?> fetchAnimeImage(String title) async {
    try {
      // Encode the title for URL parameter
      final encodedTitle = Uri.encodeComponent(title);
      final url = Uri.parse('$_baseUrl?query=$encodedTitle');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if we have titles in the response
        if (data['titles'] != null && data['titles'].isNotEmpty) {
          final firstTitle = data['titles'][0];
          
          // Check if the title has a primary image
          if (firstTitle['primaryImage'] != null && 
              firstTitle['primaryImage']['url'] != null) {
            return firstTitle['primaryImage']['url'];
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error fetching anime image: $e');
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