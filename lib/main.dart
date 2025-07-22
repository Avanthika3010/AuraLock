import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';
import 'firebase_options.dart';
import 'app/aura_lock_app.dart';
import 'services/blink_service.dart';
import 'services/typing_service.dart';
import 'services/swipe_service.dart';
import 'services/zk_score_service.dart';
import 'repository/local_storage_repo.dart';

final GetIt getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize dependency injection
  await _initializeDependencies();

  runApp(const AuraLockApp());
}

Future<void> _initializeDependencies() async {
  // Register services
  getIt.registerLazySingleton<BlinkService>(() => BlinkService());
  getIt.registerLazySingleton<TypingService>(() => TypingService());
  getIt.registerLazySingleton<SwipeService>(() => SwipeService());
  getIt.registerLazySingleton<ZKScoreService>(() => ZKScoreService());
  getIt.registerLazySingleton<LocalStorageRepo>(() => LocalStorageRepo());
}
