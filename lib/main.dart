import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/homepage_screen.dart';
import 'theme/app_theme.dart';
import 'constants/app_constants.dart';

void main() {
  runApp(const ProviderScope(child: AnimeUpdatesApp()));
}

class AnimeUpdatesApp extends StatelessWidget {
  const AnimeUpdatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomepageScreen(),
    );
  }
}
