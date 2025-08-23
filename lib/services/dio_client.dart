import 'package:dio/dio.dart';
import 'auth_service.dart';
import 'auth_storage.dart';

class AuthInterceptor extends Interceptor {
  bool _isRefreshing = false;
  final List<RequestOptions> _requests = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Add access token to requests if available
    final token = await AuthStorage.getAccessToken();
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
        return;
      }
      
      _isRefreshing = true;
      
      try {
        // Refresh the access token
        final refreshResult = await AuthService.refreshAccessToken();
        
        if (refreshResult['success'] == true) {
          // Update the token in the failed request
          final token = await AuthStorage.getAccessToken();
          final requestOptions = err.requestOptions;
          
          if (token != null) {
            requestOptions.headers['Authorization'] = 'Bearer $token';
          }
          
          // Retry the original request
          final retryResponse = await Dio().request(
            requestOptions.path,
            data: requestOptions.data,
            queryParameters: requestOptions.queryParameters,
            options: Options(
              method: requestOptions.method,
              headers: requestOptions.headers,
            ),
          );
          
          // Process queued requests
          await _processQueuedRequests(token);
          
          return handler.resolve(retryResponse);
        } else {
          // If refresh fails, logout user
          await AuthService.logout();
        }
      } catch (e) {
        // If refresh fails, logout user
        await AuthService.logout();
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
      
      for (var request in requests) {
        if (newToken != null) {
          request.headers['Authorization'] = 'Bearer $newToken';
        }
        
        try {
          await Dio().request(
            request.path,
            data: request.data,
            queryParameters: request.queryParameters,
            options: Options(
              method: request.method,
              headers: request.headers,
            ),
          );
        } catch (e) {
          // Ignore errors in queued requests
        }
      }
    }
  }
}

// Singleton Dio client with interceptor
final dioClient = Dio()..interceptors.add(AuthInterceptor());