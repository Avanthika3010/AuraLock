import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/admin_screen.dart';

class AppRoutes {
  static const String login = '/';
  static const String home = '/home';
  static const String admin = '/admin';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        home: (context) => const HomeScreen(),
        admin: (context) => const AdminScreen(),
      };
} 