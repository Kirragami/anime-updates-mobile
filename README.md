# Anime Updates - Modern Flutter App

A beautiful, modern, and scalable Flutter app for downloading anime with stunning animations and a dark theme.

## Features

- 🎨 **Modern Dark UI** - Beautiful gradient design with smooth animations
- 📱 **Cross-Platform** - Works on Android, iOS, Web, Windows, macOS, and Linux
- ⚡ **Real-time Downloads** - Individual download progress tracking
- 🔄 **Pull to Refresh** - Swipe down to refresh the anime list
- 🎭 **Smooth Animations** - Staggered animations and shimmer loading effects
- 🛡️ **Error Handling** - Comprehensive error handling with retry functionality
- 📊 **Download Progress** - Visual progress indicators for each download
- 🎯 **State Management** - Clean architecture with Provider pattern

## Architecture

The app follows a clean, maintainable architecture:

```
lib/
├── constants/          # App constants and configuration
├── models/            # Data models
├── providers/         # State management with Provider
├── screens/           # UI screens
├── services/          # API and download services
├── theme/             # App theme and styling
├── widgets/           # Reusable UI components
└── main.dart          # App entry point
```

## Key Components

### State Management
- **AnimeProvider**: Manages app state, downloads, and API calls
- Individual download tracking for each anime item
- Progress monitoring and error handling

### Services
- **ApiService**: Handles HTTP requests to your localhost API
- **DownloadService**: Manages file downloads with progress tracking

### UI Components
- **AnimeCard**: Beautiful animated cards for each anime item
- **LoadingWidget**: Shimmer loading effects
- **Error Handling**: User-friendly error states with retry options

## API Integration

The app expects your API to return data in this format:
```json
[
  {
    "title": "Anime Title",
    "downloadlink": "https://example.com/anime.mp4"
  }
]
```

## Getting Started

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Configure API Endpoint**
   - Update `lib/constants/app_constants.dart` with your API URL
   - Default: `http://localhost:8080/api/anime/downloads`

3. **Run the App**
   ```bash
   flutter run
   ```

## Supported Platforms

- ✅ Android
- ✅ iOS  
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## Dependencies

- **State Management**: `provider`
- **Animations**: `flutter_animate`, `flutter_staggered_animations`
- **UI Components**: `shimmer`, `pull_to_refresh`
- **Network**: `http`, `dio`
- **Storage**: `path_provider`, `permission_handler`

## Features in Detail

### Download Management
- Individual download tracking per anime item
- Progress indicators with percentage
- Download queue management
- Error handling with retry options

### UI/UX
- Dark theme with gradient backgrounds
- Smooth animations and transitions
- Loading states with shimmer effects
- Pull-to-refresh functionality
- Responsive design for all screen sizes

### Error Handling
- Network error detection
- Server error handling
- Permission error management
- User-friendly error messages

## Customization

### Theme
Edit `lib/theme/app_theme.dart` to customize:
- Colors and gradients
- Typography
- Component styling

### API Configuration
Update `lib/constants/app_constants.dart` to change:
- API endpoints
- Timeout settings
- Error messages

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.
