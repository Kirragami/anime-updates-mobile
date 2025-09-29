import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class AuthInterceptor extends Interceptor {
  Future<Map<String, dynamic>>? _refreshFuture;
  final Dio _dio = Dio();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
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
    if (err.response?.statusCode == 401 && 
        err.requestOptions.headers.containsKey('Authorization')) {
      
      try {
        final refreshResult = await (_refreshFuture ??= _refreshToken());
        
        if (refreshResult['success'] == true) {
          final token = AuthService.accessToken;
          final requestOptions = err.requestOptions;
          
          if (token != null) {
            requestOptions.headers['Authorization'] = 'Bearer $token';
          }
          
          final retryDio = Dio()
            ..options = _dio.options
            ..interceptors.addAll(
              _dio.interceptors.where((interceptor) => interceptor != this),
            );
          
          try {
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
            return handler.next(err);
          }
        } else {
          await AuthService.logout();
        }
      } catch (e) {
        await AuthService.logout();
      } finally {
        _refreshFuture = null;
      }
    }
    
    handler.next(err);
  }
  
  Future<Map<String, dynamic>> _refreshToken() async {
    try {
      final refreshCompleter = Completer<Map<String, dynamic>>();
      final refreshTimeout = Duration(seconds: 10);
      
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

final dioClient = Dio()..interceptors.add(AuthInterceptor());