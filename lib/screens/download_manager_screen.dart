import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/download_manager.dart';
import '../models/anime_item.dart';
import '../models/download_state.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';

class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final downloadManager = DownloadManager();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Manager'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: ValueListenableBuilder<Map<String, AnimeItem>>(
          valueListenable: downloadManager.stateNotifier,
          builder: (context, releaseStates, child) {
            // Filter to only show downloading or paused items
            final downloadingItems = releaseStates.entries.where((entry) {
              final state = entry.value.downloadState;
              return state == DownloadState.downloading || state == DownloadState.paused;
            }).toList();
            
            return Padding(
              padding: const EdgeInsets.all(AppConstants.defaultPadding),
              child: downloadingItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No ongoing downloads',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: downloadingItems.length,
                      itemBuilder: (context, index) {
                        final entry = downloadingItems[index];
                        final releaseId = entry.key;
                        final animeItem = entry.value;
                        final progress = animeItem.progress ?? 0.0;
                        final state = animeItem.downloadState;
                        
                        // Extract title and episode
                        String title = animeItem.title;
                        String episode = 'Episode ${animeItem.episode}';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppConstants.defaultPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title and episode
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  episode,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Progress bar
                                LinearProgressIndicator(
                                  value: progress / 100.0,
                                  backgroundColor: AppTheme.surfaceColor,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                ),
                                const SizedBox(height: 8),
                                
                                // Progress info
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${progress.toStringAsFixed(1)}%'),
                                    Text('${(progress * 1.2).toStringAsFixed(1)} KB/s'), // Placeholder speed
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Action buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: state == DownloadState.downloading 
                                          ? () => downloadManager.pauseRelease(releaseId)
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                      ),
                                      child: const Text('Pause'),
                                    ),
                                    ElevatedButton(
                                      onPressed: state == DownloadState.paused
                                          ? () => downloadManager.resumeRelease(releaseId)
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.secondaryColor,
                                      ),
                                      child: const Text('Resume'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _deleteDownload(downloadManager, releaseId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.errorColor,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
  }
  
  Future<void> _deleteDownload(DownloadManager downloadManager, String releaseId) async {
    try {
      await downloadManager.deleteDownload(releaseId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download deleted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting download: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting download: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}