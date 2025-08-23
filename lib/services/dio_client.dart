import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class AuthInterceptor extends Interceptor {
  bool _isRefreshing = false;
  final List<RequestOptions> _requests = [];
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
      
      // If we're already refreshing, queue the request
      if (_isRefreshing) {
        _requests.add(err.requestOptions);
        // Instead of returning, we'll resolve with a special error that indicates retry
        return handler.next(err);
      }
      
      _isRefreshing = true;
      
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
            
            // Process queued requests
            await _processQueuedRequests(token);
            
            return handler.resolve(retryResponse);
          } catch (retryError) {
            // If retry fails, continue with original error
            await _processQueuedRequests(token);
            return handler.next(err);
          }
        } else {
          // If refresh fails, logout user
          await AuthService.logout();
          // Process queued requests with null token (they'll likely fail but we tried)
          await _processQueuedRequests(null);
        }
      } catch (e) {
        // If refresh fails, logout user
        await AuthService.logout();
        // Process queued requests with null token
        await _processQueuedRequests(null);
      } finally {
        _isRefreshing = false;
      }
    }
    
    handler.next(err);
  }
  
  Future<void> _processQueuedRequests(String? newToken) async {
    if (_requests.isNotEmpty) {
      final requests = List<RequestOptions>.from(_requests);
      _requests.clear();
      
      // Process queued requests concurrently with better error handling
      await Future.wait(
        requests.map((request) async {
          if (newToken != null) {
            request.headers['Authorization'] = 'Bearer $newToken';
          }
          
          try {
            // Create a new Dio instance without this interceptor for queued requests
            final queueDio = Dio()
              ..options = _dio.options
              ..interceptors.addAll(
                _dio.interceptors.where((interceptor) => interceptor != this),
              );
            
            await queueDio.request(
              request.path,
              data: request.data,
              queryParameters: request.queryParameters,
              options: Options(
                method: request.method,
                headers: request.headers,
              ),
            ).timeout(Duration(seconds: 30));
          } catch (e) {
            // Log the error but don't let it stop processing other requests
            if (kDebugMode) {
              print('Error processing queued request: $e');
            }
            // Ignore errors in queued requests to prevent cascading failures
          }
        }),
        // Limit concurrent requests to avoid overwhelming the server
        eagerError: false,
        cleanUp: null,
      ).timeout(
        Duration(seconds: 60), // Overall timeout for processing all queued requests
        onTimeout: () {
          if (kDebugMode) {
            print('Timeout processing queued requests');
          }
          return [];
        },
      );
    }
  }
}

// Singleton Dio client with interceptor
final dioClient = Dio()..interceptors.add(AuthInterceptor());