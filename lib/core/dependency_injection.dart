import 'package:get_it/get_it.dart';

// Global GetIt instance for dependency injection
final GetIt getIt = GetIt.instance;

// Setup dependency injection
void setupDependencyInjection() {
  // Register services here
  // Example: getIt.registerSingleton<AuthService>(AuthService());
  // Example: getIt.registerLazySingleton<DatabaseService>(() => DatabaseService());
} 