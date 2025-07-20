# AuraLock Flutter Project Structure

This document describes the organization of the AuraLock Flutter project.

## Project Structure

```
lib/
├── main.dart                    # Main application entry point
├── firebase_options.dart        # Firebase configuration
├── core/                        # Core application files
│   ├── dependency_injection.dart # GetIt dependency injection setup
│   ├── app_theme.dart           # Material 3 theme configuration
│   └── app_routes.dart          # Named routes configuration
└── screens/                     # Application screens
    ├── login_screen.dart        # Login screen
    ├── home_screen.dart         # Home screen
    └── admin_screen.dart        # Admin panel screen
```

## File Descriptions

### Core Files

- **main.dart**: Application entry point with Firebase initialization and app setup
- **core/dependency_injection.dart**: GetIt setup for dependency injection
- **core/app_theme.dart**: Material 3 theme configuration (light and dark themes)
- **core/app_routes.dart**: Named routes configuration for navigation

### Screen Files

- **screens/login_screen.dart**: Login screen with email/password form
- **screens/home_screen.dart**: Main home screen with feature grid
- **screens/admin_screen.dart**: Admin panel with system management options

## Features

- ✅ Material 3 design with light/dark themes
- ✅ GetIt dependency injection setup
- ✅ Named routes navigation
- ✅ Firebase initialization
- ✅ Three main screens (Login, Home, Admin)
- ✅ Beginner-friendly code structure
- ✅ Error-free implementation

## Navigation Flow

1. **Login Screen** (`/`) - Initial route
2. **Home Screen** (`/home`) - Main application screen
3. **Admin Screen** (`/admin`) - Administrative functions

## Dependencies

- `flutter`: Core Flutter framework
- `firebase_core`: Firebase initialization
- `get_it`: Dependency injection
- `cupertino_icons`: iOS-style icons

## Getting Started

1. Run `flutter pub get` to install dependencies
2. Ensure Firebase is properly configured
3. Run `flutter run` to start the application

## Next Steps

- Add authentication services
- Implement actual login functionality
- Add state management (Provider/Bloc/Riverpod)
- Create service classes for API calls
- Add proper error handling
- Implement actual admin features 