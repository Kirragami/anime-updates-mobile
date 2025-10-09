import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

class CustomErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final bool showRetryButton;
  final String gifPath;

  const CustomErrorWidget({
    super.key,
    this.message,
    this.onRetry,
    this.showRetryButton = true,
    this.gifPath = 'assets/gifs/bocchi-the-rock-error.gif',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              child: Image.asset(
                gifPath,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                      border: Border.all(
                        color: AppTheme.errorColor,
                        width: 2.0,
                      ),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Therere was ann eRroroRoR...',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (showRetryButton && onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


class NetworkErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const NetworkErrorWidget({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CustomErrorWidget(
      message: message ?? 'Network error. Please check your connection.',
      onRetry: onRetry,
      gifPath: 'assets/gifs/bocchi-the-rock-error.gif',
    );
  }
}


class DataErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const DataErrorWidget({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CustomErrorWidget(
      message: message ?? 'Failed to load data',
      onRetry: onRetry,
      gifPath: 'assets/gifs/bocchi-the-rock-error.gif',
    );
  }
}


class AuthErrorWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AuthErrorWidget({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CustomErrorWidget(
      message: message ?? 'Authentication error',
      onRetry: onRetry,
      showRetryButton: false,
      gifPath: 'assets/gifs/bocchi-the-rock-error.gif',
    );
  }
}