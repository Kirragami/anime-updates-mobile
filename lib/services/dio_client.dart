import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class AuthInterceptor extends Interceptor {
  Future<Map<String, dynamic>>? _refreshFuture;
  final Dio _dio = Dio();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add access token to requests if available
    // Use in-memory token for better performance
    final token = AuthService.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 errors by refreshing token and retrying request
    if (err.response?.statusCode == 401 && 
        err.requestOptions.headers.containsKey('Authorization')) {
      
      try {
        // Get or create the refresh future
        final refreshResult = await (_refreshFuture ??= _refreshToken());
        
        if (refreshResult['success'] == true) {
          // Update the token in the failed request
          // Use in-memory token which is updated by refreshAccessToken
          final token = AuthService.accessToken;
          final requestOptions = err.requestOptions;
          
          if (token != null) {
            requestOptions.headers['Authorization'] = 'Bearer $token';
          }
          
          // Create a new Dio instance with same options but without this interceptor
          // to avoid infinite loops
          final retryDio = Dio()
            ..options = _dio.options
            ..interceptors.addAll(
              _dio.interceptors.where((interceptor) => interceptor != this),
            );
          
          try {
            // Retry the original request with timeout
            final retryResponse = await retryDio.request(
              requestOptions.path,
              data: requestOptions.data,
              queryParameters: requestOptions.queryParameters,
              options: Options(
                method: requestOptions.method,
                headers: requestOptions.headers,
              ),
            ).timeout(Duration(seconds: 30));
            
            return handler.resolve(retryResponse);
          } catch (retryError) {
            // If retry fails, continue with original error
            return handler.next(err);
          }
        } else {
          // If refresh fails, logout user
          await AuthService.logout();
        }
      } catch (e) {
        // If refresh fails, logout user
        await AuthService.logout();
      } finally {
        // Clear the refresh future so next 401 will trigger a new refresh
        _refreshFuture = null;
      }
    }
    
    handler.next(err);
  }
  
  Future<Map<String, dynamic>> _refreshToken() async {
    try {
      // Refresh the access token with a reasonable timeout
      final refreshCompleter = Completer<Map<String, dynamic>>();
      final refreshTimeout = Duration(seconds: 10);
      
      // Start refresh in background
      AuthService.refreshAccessToken().then((result) {
        if (!refreshCompleter.isCompleted) {
          refreshCompleter.complete(result);
        }
      }).catchError((error) {
        if (!refreshCompleter.isCompleted) {
          refreshCompleter.complete({
            'success': false,
            'message': 'Refresh failed',
            'error': error.toString(),
          });
        }
      });
      
      // Wait for refresh with timeout
      final refreshResult = await refreshCompleter.future.timeout(
        refreshTimeout,
        onTimeout: () {
          return {
            'success': false,
            'message': 'Refresh timeout',
            'error': 'Token refresh timed out',
          };
        },
      );
      
      return refreshResult;
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error during refresh',
        'error': e.toString(),
      };
    }
  }
}

// Singleton Dio client with interceptor
final dioClient = Dio()..interceptors.add(AuthInterceptor());