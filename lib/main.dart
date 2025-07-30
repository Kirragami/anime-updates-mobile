import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/anime_provider.dart';
import 'screens/anime_list_screen.dart';
import 'theme/app_theme.dart';
import 'constants/app_constants.dart';

void main() {
  runApp(const AnimeUpdatesApp());
}

class AnimeUpdatesApp extends StatelessWidget {
  const AnimeUpdatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnimeProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AnimeListScreen(),
      ),
    );
  }
}
